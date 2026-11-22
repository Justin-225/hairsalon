//
//  ContentView.swift
//  💇 髮廊預約 App（結合各種輸入元件 & 顯示 alert 的 SwiftUI App）
//
//  使用元件：TextField、Slider、Toggle、Picker（menu / segmented / wheel）、
//           DatePicker、MultiDatePicker、Stepper、TextEditor、contextMenu、
//           alert、PhotosPicker、ColorPicker
//  需求：iOS 17+（不需要任何圖片素材，圖示皆為 SF Symbols）
//

import SwiftUI
import PhotosUI

// MARK: - 資料模型
struct Designer: Hashable {
    let name: String
    let title: String
    let extraFee: Int
    let intro: String
}

struct ContentView: View {
    // MARK: - 假資料
    let designers = [
        Designer(name: "Amy", title: "店長", extraFee: 300, intro: "從業 15 年，擅長日系短髮與挑染。"),
        Designer(name: "Ben", title: "資深設計師", extraFee: 150, intro: "韓系燙髮專家，人稱捲度魔術師。"),
        Designer(name: "Cindy", title: "設計師", extraFee: 0, intro: "擅長霧感髮色，聊天很療癒。"),
        Designer(name: "Danny", title: "新秀設計師", extraFee: -100, intro: "剛升上設計師，熱情滿滿，價格最優惠。")
    ]
    let services = ["剪髮", "染髮", "燙髮", "護髮"]
    let basePrice = ["剪髮": 500, "染髮": 1800, "燙髮": 2200, "護髮": 900]
    let baseMinutes = ["剪髮": 60, "染髮": 120, "燙髮": 180, "護髮": 60]
    let hairLengths = ["短髮", "及肩", "過肩", "及腰"]
    let lengthFee = ["短髮": 0, "及肩": 200, "過肩": 400, "及腰": 600]

    // MARK: - 狀態
    @State private var name = ""                                    // TextField
    @State private var phone = ""                                   // TextField
    @State private var designerName = "Cindy"                       // Picker（menu）
    @State private var service = "剪髮"                              // Picker（segmented）
    @State private var hairLength = "及肩"                           // Picker（wheel）
    @State private var cutLength = 3.0                              // Slider
    @State private var hairColor = Color(red: 0.55, green: 0.35, blue: 0.2) // ColorPicker
    @State private var addWash = true                               // Toggle
    @State private var addScalpSpa = false                          // Toggle
    @State private var addProtect = false                           // Toggle
    @State private var people = 1                                   // Stepper
    @State private var appointment = ContentView.defaultAppointment() // DatePicker
    @State private var backupDates: Set<DateComponents> = []        // MultiDatePicker
    @State private var request = ""                                 // TextEditor
    @State private var photoItem: PhotosPickerItem?                 // PhotosPicker
    @State private var referenceImage: Image?

    // alert
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showInfoAlert = false
    @State private var showConfirm = false
    @State private var showSuccess = false
    @State private var showReset = false
    @State private var bookingNumber = 0

    // MARK: - 計算屬性
    var designer: Designer {
        designers.first { $0.name == designerName }!
    }

    var isChemical: Bool { service == "染髮" || service == "燙髮" }

    var pricePerPerson: Int {
        var price = basePrice[service]! + designer.extraFee
        if isChemical { price += lengthFee[hairLength]! }   // 頭髮越長藥水越多
        if addWash { price += 150 }
        if addScalpSpa { price += 600 }
        if addProtect && isChemical { price += 300 }
        return price
    }

    var totalPrice: Int { pricePerPerson * people }

    var totalMinutes: Int {
        var minutes = baseMinutes[service]!
        if addWash { minutes += 15 }
        if addScalpSpa { minutes += 30 }
        return minutes * people
    }

    var endTime: Date {
        appointment.addingTimeInterval(Double(totalMinutes) * 60)
    }

    var cutDescription: String {
        switch cutLength {
        case 0: return "只修髮尾"
        case ..<5: return "稍微修短"
        case ..<10: return "明顯變短"
        default: return "大改造！"
        }
    }

    var priceText: String { "$\(totalPrice.formatted())" }

    // MARK: - 畫面
    var body: some View {
        NavigationStack {
            Form {
                headerSection
                customerSection
                serviceSection
                timeSection
                requestSection
                checkoutSection
            }
            .navigationTitle("💇 髮廊預約")
            .toolbar {
                Button("重填", systemImage: "arrow.counterclockwise") {
                    showReset = true
                }
            }
            .task(id: photoItem) {
                if let data = try? await photoItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    referenceImage = Image(uiImage: uiImage)
                }
            }
            // MARK: - alert
            .alert(alertTitle, isPresented: $showInfoAlert) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .alert("確認預約內容", isPresented: $showConfirm) {
                Button("返回修改", role: .cancel) {}
                Button("確認預約") {
                    bookingNumber = Int.random(in: 1000...9999)
                    showSuccess = true
                }
            } message: {
                Text(summary)
            }
            .alert("預約成功 ✅", isPresented: $showSuccess) {
                Button("好") {}
                Button("再預約一筆") { reset() }
            } message: {
                Text("預約編號 #\(bookingNumber)\n\(name) 您好，\(designer.name) 會在 \(appointment.formatted(date: .abbreviated, time: .shortened)) 等您。\n請提早 5 分鐘到店喔！")
            }
            .alert("確定要清除所有資料？", isPresented: $showReset) {
                Button("清除", role: .destructive) { reset() }
                Button("取消", role: .cancel) {}
            }
        }
    }

    // MARK: - 各區塊
    // 預覽 + contextMenu + PhotosPicker
    var headerSection: some View {
        Section {
            VStack(spacing: 10) {
                Group {
                    if let referenceImage {
                        referenceImage
                            .resizable()
                            .scaledToFill()
                            .frame(width: 130, height: 130)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    } else {
                        Image(systemName: service == "剪髮" ? "scissors" : "comb.fill")
                            .font(.system(size: 70))
                            .foregroundStyle(service == "染髮" ? hairColor : .primary)
                            .frame(width: 130, height: 130)
                            .background(.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
                    }
                }
                // 長按：快速套用熱門套餐
                .contextMenu {
                    Button("快速整理（剪＋洗）", systemImage: "scissors") {
                        applyPackage(service: "剪髮", wash: true, spa: false, protect: false)
                    }
                    Button("質感染髮（染＋頭皮隔離）", systemImage: "paintbrush") {
                        applyPackage(service: "染髮", wash: true, spa: false, protect: true)
                    }
                    Button("放鬆一下（護髮＋頭皮 SPA）", systemImage: "leaf") {
                        applyPackage(service: "護髮", wash: true, spa: true, protect: false)
                    }
                    if referenceImage != nil {
                        Divider()
                        Button("移除參考照片", systemImage: "trash", role: .destructive) {
                            referenceImage = nil
                            photoItem = nil
                        }
                    }
                }

                Text("長按上方圖示可選熱門套餐")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(referenceImage == nil ? "上傳想要的髮型參考照" : "更換參考照",
                          systemImage: "photo.on.rectangle")
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // TextField
    var customerSection: some View {
        Section("顧客資料") {
            TextField("姓名", text: $name)
            TextField("手機（09 開頭共 10 碼）", text: $phone)
                .keyboardType(.phonePad)
        }
    }

    // Picker × 3、Slider、ColorPicker、Toggle
    var serviceSection: some View {
        Section("服務內容") {
            Picker("設計師", selection: $designerName) {
                ForEach(designers, id: \.self) { d in
                    Text("\(d.name)・\(d.title)").tag(d.name)
                }
            }
            .pickerStyle(.menu)

            Button("看看 \(designer.name) 的介紹", systemImage: "person.text.rectangle") {
                showAlert(title: "\(designer.name)（\(designer.title)）",
                          message: designer.intro + "\n指定費：\(designer.extraFee >= 0 ? "+" : "")\(designer.extraFee)")
            }

            Picker("項目", selection: $service) {
                ForEach(services, id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 4) {
                Text("目前髮長")
                Picker("目前髮長", selection: $hairLength) {
                    ForEach(hairLengths, id: \.self) { Text($0) }
                }
                .pickerStyle(.wheel)
                .frame(height: 100)
                if isChemical && lengthFee[hairLength]! > 0 {
                    Text("長髮加價 +$\(lengthFee[hairLength]!)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if service == "剪髮" {
                VStack(alignment: .leading) {
                    Text("想剪掉：\(Int(cutLength)) 公分（\(cutDescription)）")
                    Slider(value: $cutLength, in: 0...20, step: 1) {
                        Text("剪掉長度")
                    } minimumValueLabel: {
                        Text("0")
                    } maximumValueLabel: {
                        Text("20")
                    }
                }
            }

            if service == "染髮" {
                ColorPicker("想染的顏色", selection: $hairColor, supportsOpacity: false)
            }

            Toggle("洗髮 (+$150)", isOn: $addWash)
            Toggle("頭皮 SPA (+$600)", isOn: $addScalpSpa)
            if isChemical {
                Toggle("頭皮隔離保護 (+$300)", isOn: $addProtect)
            }
        }
    }

    // Stepper、DatePicker、MultiDatePicker
    var timeSection: some View {
        Section {
            Stepper("同行人數：\(people) 人", value: $people, in: 1...4)

            DatePicker("預約時間",
                       selection: $appointment,
                       in: Date()...,
                       displayedComponents: [.date, .hourAndMinute])

            Text("預計 \(endTime.formatted(date: .omitted, time: .shortened)) 結束（約 \(totalMinutes) 分鐘）")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading) {
                Text("備選日期（已選 \(backupDates.count) 天）")
                MultiDatePicker("備選日期", selection: $backupDates, in: Date()...)
            }
        } header: {
            Text("時間")
        } footer: {
            Text("營業時間 10:00–21:00，每週一公休。主要時段額滿時會改約備選日期。")
        }
    }

    // TextEditor
    var requestSection: some View {
        Section("其他需求") {
            TextEditor(text: $request)
                .frame(minHeight: 80)
                .overlay(alignment: .topLeading) {
                    if request.isEmpty {
                        Text("例如：頭皮較敏感、瀏海不要太短…")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    var checkoutSection: some View {
        Section {
            HStack {
                Text("每人 $\(pricePerPerson.formatted())")
                Spacer()
                Text("總計 \(priceText)")
                    .font(.title2.bold())
            }
            Button {
                submit()
            } label: {
                Label("送出預約", systemImage: "calendar.badge.checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - 摘要
    var summary: String {
        var lines = [
            "\(name)（\(phone)）",
            "設計師：\(designer.name)",
            "項目：\(service)　髮長：\(hairLength)",
        ]
        if service == "剪髮" { lines.append("剪掉約 \(Int(cutLength)) 公分") }
        var extras: [String] = []
        if addWash { extras.append("洗髮") }
        if addScalpSpa { extras.append("頭皮 SPA") }
        if addProtect && isChemical { extras.append("頭皮隔離") }
        lines.append("加購：\(extras.isEmpty ? "無" : extras.joined(separator: "、"))")
        lines.append("人數：\(people) 人")
        lines.append("時間：\(appointment.formatted(date: .abbreviated, time: .shortened))")
        if !backupDates.isEmpty { lines.append("備選：\(backupDates.count) 天") }
        if referenceImage != nil { lines.append("已附參考照片") }
        lines.append("總計：\(priceText)")
        return lines.joined(separator: "\n")
    }

    // MARK: - 功能
    func submit() {
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: appointment)
        let endHour = calendar.component(.hour, from: endTime)
        let endMinute = calendar.component(.minute, from: endTime)
        let weekday = calendar.component(.weekday, from: appointment) // 1 = 週日, 2 = 週一

        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            showAlert(title: "請填寫姓名", message: "設計師需要知道怎麼稱呼您 😊")
        } else if phone.count != 10 || !phone.hasPrefix("09") || Int(phone) == nil {
            showAlert(title: "手機號碼格式錯誤", message: "請輸入 09 開頭的 10 位數字")
        } else if weekday == 2 {
            showAlert(title: "週一公休", message: "請改選其他日子喔")
        } else if startHour < 10 || endHour > 21 || (endHour == 21 && endMinute > 0) || calendar.component(.day, from: endTime) != calendar.component(.day, from: appointment) {
            showAlert(title: "超出營業時間",
                      message: "這次服務約需 \(totalMinutes) 分鐘，會在 \(endTime.formatted(date: .omitted, time: .shortened)) 結束。\n營業時間為 10:00–21:00，請提早預約時間。")
        } else if service == "剪髮" && cutLength >= 15 {
            // 剪很多時先提醒再確認
            showAlert(title: "要剪 \(Int(cutLength)) 公分？✂️",
                      message: "剪了就回不去了喔！確定的話請把長度調到 14 公分以下，或到店再跟設計師討論。")
        } else {
            showConfirm = true
        }
    }

    func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showInfoAlert = true
    }

    func applyPackage(service: String, wash: Bool, spa: Bool, protect: Bool) {
        self.service = service
        addWash = wash
        addScalpSpa = spa
        addProtect = protect
    }

    static func defaultAppointment() -> Date {
        // 預設明天下午 2 點
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        return Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: tomorrow)!
    }

    func reset() {
        name = ""
        phone = ""
        designerName = "Cindy"
        service = "剪髮"
        hairLength = "及肩"
        cutLength = 3
        hairColor = Color(red: 0.55, green: 0.35, blue: 0.2)
        addWash = true
        addScalpSpa = false
        addProtect = false
        people = 1
        appointment = ContentView.defaultAppointment()
        backupDates = []
        request = ""
        photoItem = nil
        referenceImage = nil
    }
}

#Preview {
    ContentView()
}
