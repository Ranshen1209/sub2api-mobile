import SakrylleShared
import SwiftUI

struct CreateUserView: View {
    @Environment(\.adminAPIClient) private var client
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var notes = ""
    @State private var role = "user"
    @State private var status = "active"
    @State private var balance = ""
    @State private var concurrency = ""
    @State private var extraJSON = ""
    @State private var errorText: String?

    var body: some View {
        ScreenScaffold("创建用户") {
            ListCard {
                TextField("邮箱", text: $email).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
                SecureField("密码", text: $password).textFieldStyle(.roundedBorder)
                TextField("用户名", text: $username).textFieldStyle(.roundedBorder)
                TextField("备注", text: $notes).textFieldStyle(.roundedBorder)
                Picker("角色", selection: $role) { Text("user").tag("user"); Text("admin").tag("admin") }.pickerStyle(.segmented)
                Picker("状态", selection: $status) { Text("active").tag("active"); Text("disabled").tag("disabled") }.pickerStyle(.segmented)
                TextField("余额", text: $balance).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                TextField("并发", text: $concurrency).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                TextField(#"extra JSON {"tier":"pro"}"#, text: $extraJSON, axis: .vertical).textFieldStyle(.roundedBorder)
                if let errorText { Text(errorText).font(.footnote).foregroundStyle(ColorPalette.danger) }
                Button("创建用户") { Task { await submit() } }.buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private func submit() async {
        guard let emailValue = trimNil(email), let passwordValue = trimNil(password) else {
            errorText = "邮箱和密码不能为空。"
            return
        }
        do {
            let body = CreateUserRequestDTO(
                email: emailValue,
                password: passwordValue,
                username: trimNil(username),
                notes: trimNil(notes),
                role: role,
                status: status,
                balance: Double(balance),
                concurrency: Int(concurrency),
                extra: try parseScalarObject(extraJSON)
            )
            _ = try await client.createUser(body)
            dismiss()
        } catch {
            errorText = errorMessage(error)
        }
    }
}
