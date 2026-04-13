
import Foundation

struct Goal: Identifiable, Codable {
    let id: UUID
    var name: String
    var targetAmount: Double
    var currentlySaved: Double = 0
    var targetDate: Date
    var monthlyGoal: Double
    let iconName: String
    let imageName: String?
    var isCompleted: Bool
    var completedOn: Date?
    var pickedImageURL: URL? = nil
    
    enum CodingKeys: String, CodingKey {
           case id, name, targetAmount, currentlySaved,
                targetDate, monthlyGoal, iconName,
                imageName, isCompleted, completedOn
       }

    
    init(
        id: UUID = UUID(),
        name: String,
        targetAmount: Double,
        currentlySaved: Double = 0,
        targetDate: Date,
        monthlyGoal: Double,
        iconName: String,
        imageName: String? = nil,
        isCompleted: Bool = false,
        completedOn: Date? = nil
    ) {
        self.id             = id
        self.name           = name
        self.targetAmount   = targetAmount
        self.currentlySaved = currentlySaved
        self.targetDate     = targetDate
        self.monthlyGoal    = monthlyGoal
        self.iconName       = iconName
        self.imageName      = imageName
        self.isCompleted    = isCompleted
        self.completedOn    = completedOn
    }
    
    var progress: Float {
        guard targetAmount > 0 else { return 0 }
        return Float(min(currentlySaved / targetAmount, 1.0))
    }
    
    var amountToGo: Double {
        max(targetAmount - currentlySaved, 0)
    }
}
