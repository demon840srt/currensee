import Foundation

/// Whether an alert can fire with the current watch list (SPEC F28: thresholds are in a base currency).
public enum AlertActivity: Sendable, Equatable {
    case active
    /// Set in another base currency (holds that base); kept but never evaluated until the base matches (ADR-0021).
    case wrongBase(String)
    /// The currency is no longer in the watch list, so no quotes arrive for it.
    case notWatched(String)
}

public struct AlertEvaluation: Sendable, Equatable {
    /// All alerts with updated arm state.
    public let alerts: [RateAlert]
    /// Alerts that crossed their threshold in this evaluation (one notification each).
    public let fired: [RateAlert]
}

/// Crossing detection (SPEC F29): an armed alert fires when the rate goes strictly past the threshold, then
/// disarms; it re-arms when the rate is back at or on the other side of the threshold. Exactly at the threshold
/// never fires. Only quotes fetched since `freshSince` count, so cached or held values can't trigger it.
public enum AlertEvaluator {
    public static func activity(of alert: RateAlert, watchList: WatchList) -> AlertActivity {
        guard alert.baseCode == watchList.baseCode else { return .wrongBase(alert.baseCode) }
        guard watchList.orderedCodes.contains(alert.quoteCode) else { return .notWatched(alert.quoteCode) }
        return .active
    }

    public static func isMet(direction: AlertDirection, threshold: Decimal, value: Decimal) -> Bool {
        switch direction {
        case .above: value > threshold
        case .below: value < threshold
        }
    }

    /// A new alert whose condition is already true starts disarmed: it notifies on the next real crossing.
    public static func initialArmState(direction: AlertDirection, threshold: Decimal, current: Decimal?) -> Bool {
        guard let current else { return true }
        return !isMet(direction: direction, threshold: threshold, value: current)
    }

    public static func evaluate(alerts: [RateAlert], quotes: [String: RateQuote], watchList: WatchList,
                                freshSince: Date, now: Date) -> AlertEvaluation {
        var fired: [RateAlert] = []
        let updated = alerts.map { original -> RateAlert in
            guard activity(of: original, watchList: watchList) == .active,
                  let quote = quotes[original.quoteCode],
                  quote.baseCode == original.baseCode,
                  quote.fetchedAt >= freshSince
            else { return original }
            var alert = original
            let met = isMet(direction: alert.direction, threshold: alert.threshold, value: quote.value)
            if alert.isArmed && met {
                alert.isArmed = false
                alert.lastTriggeredAt = now
                fired.append(alert)
            } else if !alert.isArmed && !met {
                alert.isArmed = true
            }
            return alert
        }
        return AlertEvaluation(alerts: updated, fired: fired)
    }
}

/// Parts of a notification ("USD rose above 3.8000 ₪"); the app localizes the sentence.
public struct AlertMessage: Sendable, Equatable {
    public let code: String
    public let direction: AlertDirection
    /// Threshold formatted with the display precision rule, plus the base symbol.
    public let threshold: String

    public static func make(for alert: RateAlert, formatter: RateFormatter) -> AlertMessage {
        let number = formatter.number(alert.threshold, quoteCode: alert.quoteCode)
        return AlertMessage(code: alert.quoteCode, direction: alert.direction,
                            threshold: "\(number) \(formatter.symbol(for: alert.baseCode))")
    }
}
