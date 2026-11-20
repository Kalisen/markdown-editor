import AppKit

/// The menu bar. Document actions go to the first responder chain, where the window controller handles them.
@MainActor
enum MainMenu {
    static func make() -> NSMenu {
        let main = NSMenu()
        for menu in [applicationMenu(), fileMenu(), editMenu(), windowMenu(), helpMenu()] {
            let item = NSMenuItem()
            item.submenu = menu
            main.addItem(item)
        }
        return main
    }

    private static func item(_ title: String, _ action: Selector?, _ key: String = "", _ modifiers: NSEvent.ModifierFlags = [.command]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        return item
    }

    private static func applicationMenu() -> NSMenu {
        let name = MainWindowController.appTitle
        let menu = NSMenu()
        menu.addItem(item("About \(name)", #selector(NSApplication.orderFrontStandardAboutPanel(_:))))
        menu.addItem(.separator())
        let services = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        services.submenu = NSMenu()
        NSApp.servicesMenu = services.submenu
        menu.addItem(services)
        menu.addItem(.separator())
        menu.addItem(item("Hide \(name)", #selector(NSApplication.hide(_:)), "h"))
        menu.addItem(item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]))
        menu.addItem(item("Show All", #selector(NSApplication.unhideAllApplications(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Quit \(name)", #selector(NSApplication.terminate(_:)), "q"))
        return menu
    }

    private static func fileMenu() -> NSMenu {
        let menu = NSMenu(title: "File")
        menu.addItem(item("New", #selector(MainWindowController.newFile(_:)), "n"))
        menu.addItem(item("Open…", #selector(MainWindowController.openFile(_:)), "o"))
        menu.addItem(.separator())
        menu.addItem(item("Save", #selector(MainWindowController.saveFile(_:)), "s"))
        menu.addItem(item("Save As…", #selector(MainWindowController.saveFileAs(_:)), "s", [.command, .shift]))
        menu.addItem(item("Reload File", #selector(MainWindowController.reloadFile(_:)), "r"))
        menu.addItem(.separator())
        menu.addItem(item("Export to HTML…", #selector(MainWindowController.exportToHTML(_:))))
        menu.addItem(item("Export to PDF…", #selector(MainWindowController.exportToPDF(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Close", #selector(NSWindow.performClose(_:)), "w"))
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem(item("Undo", Selector(("undo:")), "z"))
        menu.addItem(item("Redo", Selector(("redo:")), "z", [.command, .shift]))
        menu.addItem(.separator())
        menu.addItem(item("Cut", #selector(NSText.cut(_:)), "x"))
        menu.addItem(item("Copy", #selector(NSText.copy(_:)), "c"))
        menu.addItem(item("Paste", #selector(NSText.paste(_:)), "v"))
        menu.addItem(item("Select All", #selector(NSText.selectAll(_:)), "a"))
        menu.addItem(.separator())

        let find = NSMenu(title: "Find")
        func findItem(_ title: String, _ action: NSTextFinder.Action, _ key: String, _ modifiers: NSEvent.ModifierFlags = [.command]) -> NSMenuItem {
            let entry = item(title, #selector(NSTextView.performFindPanelAction(_:)), key, modifiers)
            entry.tag = action.rawValue
            return entry
        }
        find.addItem(findItem("Find…", .showFindInterface, "f"))
        find.addItem(findItem("Find and Replace…", .showReplaceInterface, "f", [.command, .option]))
        find.addItem(findItem("Find Next", .nextMatch, "g"))
        find.addItem(findItem("Find Previous", .previousMatch, "g", [.command, .shift]))
        find.addItem(findItem("Use Selection for Find", .setSearchString, "e"))
        let findItemMenu = NSMenuItem(title: "Find", action: nil, keyEquivalent: "")
        findItemMenu.submenu = find
        menu.addItem(findItemMenu)
        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: "Window")
        menu.addItem(item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"))
        menu.addItem(item("Zoom", #selector(NSWindow.performZoom(_:))))
        NSApp.windowsMenu = menu
        return menu
    }

    private static func helpMenu() -> NSMenu {
        let menu = NSMenu(title: "Help")
        menu.addItem(item("Plugins…", #selector(MainWindowController.showPlugins(_:))))
        NSApp.helpMenu = menu
        return menu
    }
}
