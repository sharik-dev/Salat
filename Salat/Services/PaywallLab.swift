//
//  PaywallLab.swift
//  Salat
//
//  The paywall A/B tests (28/11/2026, after Marvin's paywall research — same
//  scheme as MeTube). Four independent tests, 50/50 each, drawn once per
//  install and kept:
//
//    cta    A: "3 days free, then … / month"     B: "Continue"
//    pre    A: straight to the paywall           B: 2 screens first ("try it
//           free" → "we'll remind you before it ends" + notification
//           permission), then the paywall and its timeline
//    exit   A: nothing                           B: backing out of the App
//           Store sheet offers the yearly plan (cheaper per month), once
//    weekly A: monthly plan                      B: weekly plan
//
//  Every paywall event carries the arms (`x_cta`, `x_pre`, `x_exit`,
//  `x_weekly`); app-metrics breaks them down per property. Conversion =
//  `pro_purchase` / `paywall_view` per arm. An arm that can't be shown (weekly
//  not approved yet, no trial) is logged as A: we measure what was shown.
//
//  DEBUG: `-lab.cta b` (etc.) forces an arm at launch.
//

import Foundation

enum PaywallLab {

    enum Test: String, CaseIterable { case cta, pre, exit, weekly }

    /// Set by `Store` once products load: false while the weekly plan isn't on sale.
    @MainActor static var weeklyAvailable = false
    /// Same for the yearly plan of the exit offer.
    @MainActor static var yearlyAvailable = false
    /// The account may take a free trial: the pre-screens only exist then.
    @MainActor static var trialOffered = false

    static func isB(_ test: Test) -> Bool { arm(test) == "b" }

    static func arm(_ test: Test) -> String {
        let key = "lab." + test.rawValue
        let d = UserDefaults.standard
        if let v = d.string(forKey: key), v == "a" || v == "b" { return v }
        let v = Bool.random() ? "b" : "a"
        d.set(v, forKey: key)
        return v
    }

    /// The weekly plan is what the paywall sells.
    @MainActor static var sellsWeekly: Bool { isB(.weekly) && weeklyAvailable }

    @MainActor
    static var props: [String: String] {
        var p: [String: String] = [:]
        for t in Test.allCases { p["x_" + t.rawValue] = arm(t) }
        if !sellsWeekly { p["x_weekly"] = "a" }
        if !yearlyAvailable { p["x_exit"] = "a" }
        if !trialOffered { p["x_pre"] = "a" }
        return p
    }

    @MainActor
    static func track(_ name: String, _ extra: [String: String] = [:]) {
        Telemetry.shared.track(name, props: props.merging(extra) { $1 })
    }
}
