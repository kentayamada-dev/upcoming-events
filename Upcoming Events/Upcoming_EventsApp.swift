import MenuBarExtraAccess
import SwiftUI

struct ListItemModel: Identifiable {
  private(set) var id = UUID()
  private(set) var text: String
}

final class ListModel: ObservableObject {
  @Published var listItems = [ListItemModel(text: "Google"),
                              ListItemModel(text: "Apple"),
                              ListItemModel(text: "Facebook")]
}

struct ListItemView: View {
  private(set) var listItem: ListItemModel

  var body: some View {
    print("ListItemView")
    return Text(listItem.text)
      .onTapGesture { value in
        print(value)
      }
  }
}

struct LabelView: View {

  var body: some View {
    print("LabelView")
    return VStack {
      Text("LabelView")
    }
  }
}

struct ListView: View {
  @ObservedObject var listModel = ListModel()

  var body: some View {
    print("ListView")
    return VStack {
      List {
        ForEach(listModel.listItems) { item in
          ListItemView(listItem: item)
        }
      }
      Button(action: {
        listModel.listItems.append(ListItemModel(text: "Amazon"))
      }, label: {
        Text("Add Item")
      })
    }
  }
}

struct SettingsTabView: View {
  
  var body: some View {
    print("SettingsTabView")
    return VStack {
      Text("SettingsTabView")
    }
  }
}

@main
struct Upcoming_EventsApp: App {
  @State private var isMenuPresented = true

  var body: some Scene {
    MenuBarExtra {
      VStack(spacing: 5) {
        ListView()
        Divider()
        Button {
          isMenuPresented = false
          NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
          NSApp.activate(ignoringOtherApps: true)
        } label: {
          Text("Settings")
            .frame(maxWidth: .infinity)
        }
        Button {
          NSApplication.shared.terminate(self)
        } label: {
          Text("Quit")
            .frame(maxWidth: .infinity)
        }
      }.frame(width: 200).padding(5)
    } label: {
      LabelView()
    }.menuBarExtraStyle(.window).menuBarExtraAccess(isPresented: $isMenuPresented)
    Settings {
      TabView {
        SettingsTabView()
          .tabItem {
            Label("Settings", systemImage: "gear")
          }
        Text("About")
          .tabItem {
            Label("About", systemImage: "info.circle")
          }
      }.frame(width: 500, height: 200)
    }
  }
}
