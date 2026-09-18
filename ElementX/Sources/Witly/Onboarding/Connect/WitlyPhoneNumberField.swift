//
// Copyright 2026 Witly
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import SwiftUI

/// flag · display name · dial code (no leading "+").
nonisolated struct WitlyCountry: Identifiable, Equatable, Sendable {
    var id: String {
        dialCode + name
    }
    
    let flag: String
    let name: String
    let dialCode: String
}

nonisolated enum WitlyCountries {
    static let all: [WitlyCountry] = [
        .init(flag: "🇬🇧", name: "United Kingdom", dialCode: "44"),
        .init(flag: "🇺🇸", name: "United States", dialCode: "1"),
        .init(flag: "🇨🇦", name: "Canada", dialCode: "1"),
        .init(flag: "🇦🇺", name: "Australia", dialCode: "61"),
        .init(flag: "🇩🇪", name: "Germany", dialCode: "49"),
        .init(flag: "🇫🇷", name: "France", dialCode: "33"),
        .init(flag: "🇮🇹", name: "Italy", dialCode: "39"),
        .init(flag: "🇪🇸", name: "Spain", dialCode: "34"),
        .init(flag: "🇳🇱", name: "Netherlands", dialCode: "31"),
        .init(flag: "🇧🇪", name: "Belgium", dialCode: "32"),
        .init(flag: "🇨🇭", name: "Switzerland", dialCode: "41"),
        .init(flag: "🇦🇹", name: "Austria", dialCode: "43"),
        .init(flag: "🇸🇪", name: "Sweden", dialCode: "46"),
        .init(flag: "🇳🇴", name: "Norway", dialCode: "47"),
        .init(flag: "🇩🇰", name: "Denmark", dialCode: "45"),
        .init(flag: "🇫🇮", name: "Finland", dialCode: "358"),
        .init(flag: "🇵🇱", name: "Poland", dialCode: "48"),
        .init(flag: "🇵🇹", name: "Portugal", dialCode: "351"),
        .init(flag: "🇮🇪", name: "Ireland", dialCode: "353"),
        .init(flag: "🇬🇷", name: "Greece", dialCode: "30"),
        .init(flag: "🇨🇿", name: "Czech Republic", dialCode: "420"),
        .init(flag: "🇭🇺", name: "Hungary", dialCode: "36"),
        .init(flag: "🇷🇴", name: "Romania", dialCode: "40"),
        .init(flag: "🇺🇦", name: "Ukraine", dialCode: "380"),
        .init(flag: "🇹🇷", name: "Turkey", dialCode: "90"),
        .init(flag: "🇮🇳", name: "India", dialCode: "91"),
        .init(flag: "🇵🇰", name: "Pakistan", dialCode: "92"),
        .init(flag: "🇧🇩", name: "Bangladesh", dialCode: "880"),
        .init(flag: "🇱🇰", name: "Sri Lanka", dialCode: "94"),
        .init(flag: "🇨🇳", name: "China", dialCode: "86"),
        .init(flag: "🇯🇵", name: "Japan", dialCode: "81"),
        .init(flag: "🇰🇷", name: "South Korea", dialCode: "82"),
        .init(flag: "🇮🇩", name: "Indonesia", dialCode: "62"),
        .init(flag: "🇲🇾", name: "Malaysia", dialCode: "60"),
        .init(flag: "🇸🇬", name: "Singapore", dialCode: "65"),
        .init(flag: "🇹🇭", name: "Thailand", dialCode: "66"),
        .init(flag: "🇵🇭", name: "Philippines", dialCode: "63"),
        .init(flag: "🇻🇳", name: "Vietnam", dialCode: "84"),
        .init(flag: "🇭🇰", name: "Hong Kong", dialCode: "852"),
        .init(flag: "🇹🇼", name: "Taiwan", dialCode: "886"),
        .init(flag: "🇦🇪", name: "UAE", dialCode: "971"),
        .init(flag: "🇸🇦", name: "Saudi Arabia", dialCode: "966"),
        .init(flag: "🇶🇦", name: "Qatar", dialCode: "974"),
        .init(flag: "🇰🇼", name: "Kuwait", dialCode: "965"),
        .init(flag: "🇧🇭", name: "Bahrain", dialCode: "973"),
        .init(flag: "🇴🇲", name: "Oman", dialCode: "968"),
        .init(flag: "🇯🇴", name: "Jordan", dialCode: "962"),
        .init(flag: "🇪🇬", name: "Egypt", dialCode: "20"),
        .init(flag: "🇲🇦", name: "Morocco", dialCode: "212"),
        .init(flag: "🇹🇳", name: "Tunisia", dialCode: "216"),
        .init(flag: "🇩🇿", name: "Algeria", dialCode: "213"),
        .init(flag: "🇳🇬", name: "Nigeria", dialCode: "234"),
        .init(flag: "🇿🇦", name: "South Africa", dialCode: "27"),
        .init(flag: "🇰🇪", name: "Kenya", dialCode: "254"),
        .init(flag: "🇬🇭", name: "Ghana", dialCode: "233"),
        .init(flag: "🇹🇿", name: "Tanzania", dialCode: "255"),
        .init(flag: "🇪🇹", name: "Ethiopia", dialCode: "251"),
        .init(flag: "🇧🇷", name: "Brazil", dialCode: "55"),
        .init(flag: "🇲🇽", name: "Mexico", dialCode: "52"),
        .init(flag: "🇦🇷", name: "Argentina", dialCode: "54"),
        .init(flag: "🇨🇴", name: "Colombia", dialCode: "57"),
        .init(flag: "🇨🇱", name: "Chile", dialCode: "56"),
        .init(flag: "🇵🇪", name: "Peru", dialCode: "51"),
        .init(flag: "🇳🇿", name: "New Zealand", dialCode: "64"),
        .init(flag: "🇷🇺", name: "Russia", dialCode: "7")
    ]
    
    static let `default` = all[0] // United Kingdom
    
    /// Split a full E.164 value (e.g. "+447911123456") into its country + national number by
    /// matching the longest known dial-code prefix.
    static func parse(_ value: String) -> (country: WitlyCountry, national: String) {
        guard value.hasPrefix("+") else { return (WitlyCountries.default, value) }
        let digits = String(value.dropFirst())
        for length in stride(from: 4, through: 1, by: -1) where digits.count >= length {
            let prefix = String(digits.prefix(length))
            if let match = all.first(where: { $0.dialCode == prefix }) {
                return (match, String(digits.dropFirst(length)))
            }
        }
        return (WitlyCountries.default, value)
    }
}

/// A country-code selector + national-number field, producing an E.164 value (e.g.
/// "+447911123456"). Mirrors the web fork's dependency-free `PhoneInput.tsx`.
struct WitlyPhoneNumberField: View {
    @Binding var value: String
    @State private var isPickerPresented = false
    
    private var parsed: (country: WitlyCountry, national: String) {
        WitlyCountries.parse(value)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Button {
                isPickerPresented = true
            } label: {
                HStack(spacing: 4) {
                    Text(parsed.country.flag)
                    Text("+\(parsed.country.dialCode)")
                        .foregroundColor(.compound.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.compound.textSecondary)
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(Color.compound.bgSubtleSecondaryLevel0)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Country code")
            
            TextField("Phone number", text: Binding(get: { parsed.national },
                                                    set: { newValue in
                                                        value = "+\(parsed.country.dialCode)\(newValue.filter(\.isNumber))"
                                                    }))
                                                    .keyboardType(.numberPad)
                                                    .textFieldStyle(.compound(labelText: nil, footerText: nil, state: .default,
                                                                              accessibilityIdentifier: "witlyWhatsAppPhoneNumberField"))
        }
        .sheet(isPresented: $isPickerPresented) {
            WitlyCountryPickerSheet(selection: parsed.country) { country in
                value = "+\(country.dialCode)\(parsed.national)"
            }
        }
    }
}

private struct WitlyCountryPickerSheet: View {
    let selection: WitlyCountry
    let onSelect: (WitlyCountry) -> Void
    
    @State private var search = ""
    @Environment(\.dismiss) private var dismiss
    
    private var filtered: [WitlyCountry] {
        guard !search.isEmpty else { return WitlyCountries.all }
        return WitlyCountries.all.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.dialCode.contains(search)
        }
    }
    
    var body: some View {
        NavigationStack {
            List(filtered) { country in
                Button {
                    onSelect(country)
                    dismiss()
                } label: {
                    HStack {
                        Text(country.flag)
                        Text(country.name)
                            .foregroundColor(.compound.textPrimary)
                        Spacer()
                        Text("+\(country.dialCode)")
                            .foregroundColor(.compound.textSecondary)
                    }
                }
            }
            .searchable(text: $search, prompt: "Search country or code")
            .navigationTitle("Select country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.actionCancel) { dismiss() }
                }
            }
        }
    }
}
