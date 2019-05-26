

import QuartzCore

//installHelper()

let CONFIG_PATH = "/usr/local/etc/butterfly_fixer.plist";

struct Config {
    
    let blacklist: [Int64]
    let timeout: Int
    
    static func loadFromFile() -> Config {
        let myDict = NSDictionary(contentsOfFile: CONFIG_PATH)!
        let blacklisted = myDict["blacklisted_keys"]! as! [Int64]
        let timeout = (myDict["timeout"]! as! Int)   * 1_000_000
        return Config(blacklist: blacklisted, timeout: timeout)
    }
}


struct State {
    var lastTimestamp: CGEventTimestamp?
    var lastEventType: CGEventType?
    var lastEventKeyCode: Int64?
}

var state = State()
let config = Config.loadFromFile()

NSLog("started")

NSLog("\(config)")

func callback(proxy: CGEventTapProxy, evType: CGEventType, ev: CGEvent, ref: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {

    
    let keycode = ev.getIntegerValueField(.keyboardEventKeycode)
    #if LOG
    NSLog("ev_type: \(evType == .keyDown ? "keydown" : "keyup"), code: \(keycode)")
    #endif
    let originalEvent = Unmanaged.passUnretained(ev)
    
    if !config.blacklist.contains(keycode) {
        return originalEvent
    }
    
    guard let lastEventType = state.lastEventType else {
        state.lastEventType = evType
        return originalEvent
    }
    state.lastEventType = evType

    guard let lastEventKeyCode = state.lastEventKeyCode, lastEventKeyCode == keycode else {
        state.lastEventKeyCode = keycode
        return originalEvent
    }
    state.lastEventKeyCode = keycode
    
    guard lastEventType == .keyUp && evType == .keyDown else {
        return originalEvent
    }
    
    guard let lastTimestamp = state.lastTimestamp else {
        state.lastTimestamp = ev.timestamp
        return originalEvent
    }
    state.lastTimestamp = ev.timestamp

    let timeInterval = (ev.timestamp - lastTimestamp)
    
    if (timeInterval < config.timeout) {
        NSLog("🚨 blocked: \(timeInterval / 1_000_000)ms")
        return nil
    }
    else {
        #if LOG
        NSLog("not blocked: \(timeInterval / 1_000_000)ms")
        #endif
    }
    
    return originalEvent
}

let EVENTS = CGEventMask(1<<CGEventType.keyDown.rawValue | 1<<CGEventType.keyUp.rawValue)


let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .defaultTap, eventsOfInterest: EVENTS, callback: callback, userInfo: nil
    )!

let source = CFMachPortCreateRunLoopSource(nil, tap, 0)!


CFRunLoopAddSource(CFRunLoopGetCurrent()!, source, CFRunLoopMode.commonModes)
CFRunLoopRun()

