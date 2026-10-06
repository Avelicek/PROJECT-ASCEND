import Foundation

public enum Muscle: String, Codable, CaseIterable, Sendable, Identifiable {
    case upperPectoral, midPectoral, lowerPectoral
    case anteriorDeltoid, lateralDeltoid, posteriorDeltoid
    case bicepsLongHead, bicepsShortHead, brachialis
    case tricepsLongHead, tricepsLateralHead, tricepsMedialHead
    case forearmFlexors, forearmExtensors
    case upperTrapezius, middleTrapezius, lowerTrapezius, rhomboids, latissimus, serratusAnterior
    case spinalErectors, rectusAbdominis, obliques, transverseAbdominis
    case gluteusMaximus, gluteusMedius, gluteusMinimus, hipFlexors, adductors
    case rectusFemoris, vastusLateralis, vastusMedialis, vastusIntermedius
    case bicepsFemoris, semitendinosus, semimembranosus
    case gastrocnemius, soleus, tibialisAnterior

    public var id: String { rawValue }
    public var group: String {
        switch self {
        case .upperPectoral, .midPectoral, .lowerPectoral: "Chest"
        case .anteriorDeltoid, .lateralDeltoid, .posteriorDeltoid: "Shoulders"
        case .bicepsLongHead, .bicepsShortHead, .brachialis, .tricepsLongHead, .tricepsLateralHead,
             .tricepsMedialHead, .forearmFlexors, .forearmExtensors: "Arms"
        case .upperTrapezius, .middleTrapezius, .lowerTrapezius, .rhomboids, .latissimus,
             .spinalErectors, .serratusAnterior: "Back"
        case .rectusAbdominis, .obliques, .transverseAbdominis: "Core"
        case .gluteusMaximus, .gluteusMedius, .gluteusMinimus: "Glutes"
        case .gastrocnemius, .soleus, .tibialisAnterior: "Calves"
        default: "Legs"
        }
    }
    public var title: String {
        rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized
    }
}
