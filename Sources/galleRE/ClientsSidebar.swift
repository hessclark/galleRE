import SwiftUI

struct ClientsSidebar: View {
    @EnvironmentObject var clients: ClientsStore
    @Binding var selectedClient: URL?

    @State private var pendingArchive: ClientFolder?
    @State private var showArchived = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if clients.rootURL == nil {
                emptyState
            } else {
                clientList
            }
        }
        .frame(minWidth: 200)
        .confirmationDialog(
            "Archive “\(pendingArchive?.name ?? "")”?",
            isPresented: Binding(get: { pendingArchive != nil }, set: { if !$0 { pendingArchive = nil } }),
            titleVisibility: .visible
        ) {
            Button("Archive Client") {
                if let c = pendingArchive {
                    if selectedClient == c.url { selectedClient = nil }
                    clients.archive(c)
                }
                pendingArchive = nil
            }
            Button("Cancel", role: .cancel) { pendingArchive = nil }
        } message: {
            Text("This moves the folder into the “\(ClientsStore.archiveFolderName)” folder. You can restore it anytime.")
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.2.crop.square.stack").foregroundStyle(Color.brand)
            Text("Clients").font(.headline)
            Spacer()
            if clients.rootURL != nil {
                Button { clients.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless).help("Refresh")
                Button { chooseRoot() } label: { Image(systemName: "folder.badge.gearshape") }
                    .buttonStyle(.borderless).help("Change clients folder")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "folder.badge.person.crop")
                .font(.system(size: 34)).foregroundStyle(.secondary)
            Text("Point galleRE at the folder that holds your listing-client folders.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 16)
            Button("Choose Clients Folder…") { chooseRoot() }
                .buttonStyle(.borderedProminent).tint(.brand)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var clientList: some View {
        List(selection: $selectedClient) {
            Section(clients.rootName) {
                if clients.clients.isEmpty {
                    Text("No client folders yet").foregroundStyle(.secondary).font(.callout)
                }
                ForEach(clients.clients) { c in
                    row(c, archived: false).tag(c.url)
                }
            }

            if !clients.archived.isEmpty {
                Section(isExpanded: $showArchived) {
                    ForEach(clients.archived) { c in
                        row(c, archived: true).tag(c.url)
                    }
                } header: {
                    Text("Archived (\(clients.archived.count))")
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func row(_ c: ClientFolder, archived: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: archived ? "archivebox" : "house")
                .foregroundStyle(archived ? .secondary : Color.brand)
            VStack(alignment: .leading, spacing: 1) {
                Text(c.name).lineLimit(1)
                Text("\(c.photoCount) photo\(c.photoCount == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .contextMenu {
            if archived {
                Button { clients.restore(c) } label: { Label("Restore Client", systemImage: "arrow.uturn.backward") }
            } else {
                Button { pendingArchive = c } label: { Label("Archive Client", systemImage: "archivebox") }
            }
            Button { NSWorkspace.shared.open(c.url) } label: { Label("Reveal in Finder", systemImage: "folder") }
        }
        .swipeActions(edge: .trailing) {
            if archived {
                Button { clients.restore(c) } label: { Label("Restore", systemImage: "arrow.uturn.backward") }.tint(.blue)
            } else {
                Button { pendingArchive = c } label: { Label("Archive", systemImage: "archivebox") }.tint(.orange)
            }
        }
    }

    private func chooseRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose the folder that contains your listing-client folders"
        if panel.runModal() == .OK, let url = panel.url {
            clients.setRoot(url)
        }
    }
}
