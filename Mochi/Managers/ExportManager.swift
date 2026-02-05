import SwiftUI
import SwiftData

class ExportManager {
    static let shared = ExportManager()
    
    func generateCSV(items: [Item], settings: SettingsManager) -> URL? {
        var csvString = "Date,Time,Amount,Currency,Payment Method,Note\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        for item in items {
            let date = dateFormatter.string(from: item.timestamp)
            let time = timeFormatter.string(from: item.timestamp)
            let amount = String(format: "%.2f", item.amount)
            let currency = settings.customCurrencyCode.isEmpty ? "Local" : settings.customCurrencyCode
            let method = settings.getPaymentMethod(by: item.paymentMethodId ?? "")?.name ?? "Cash"
            let note = (item.note ?? "").replacingOccurrences(of: ",", with: " ")
            
            csvString += "\(date),\(time),\(amount),\(currency),\(method),\(note)\n"
        }
        
        let fileName = "Mochi_Export_\(Date().formatted(.dateTime.year().month().day())).csv"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: path, atomically: true, encoding: .utf8)
            return path
        } catch {
            #if DEBUG
            print("Export Error: \(error)")
            #endif
            return nil
        }
    }
}
