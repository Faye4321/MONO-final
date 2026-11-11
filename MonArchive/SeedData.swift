import Foundation

enum SeedData {
    static let items: [CollectibleItem] = [
        CollectibleItem(
            id: UUID(uuidString: "C7EB487F-EBDE-57EB-A5FC-A8CBFAD4C45B")!,
            title: "Nothing’s Gonna Change My Love for You",
            creator: "Glenn Medeiros",
            year: 1987,
            category: .vinyl,
            note: "7-inch / 12-inch single · 3 tracks · retro pop, love song · Launch reference: US$5 · Current reference: US$8",
            colorA: "355C7D",
            colorB: "C06C84",
            imageName: "album_001"
        ),
        CollectibleItem(
            id: UUID(uuidString: "182F990F-6AB5-5FF8-BBA5-A260187F35EF")!,
            title: "Blue Neighbourhood",
            creator: "Troye Sivan",
            year: 2015,
            category: .vinyl,
            note: "2LP (Deluxe Edition) · 16 tracks · pop, electropop · Launch reference: US$35 · Current reference: US$52",
            colorA: "355C7D",
            colorB: "C06C84",
            imageName: "album_002"
        ),
        CollectibleItem(
            id: UUID(uuidString: "5F04EAC7-BE60-5DA4-B7AB-52B4EBC5B446")!,
            title: "Animal",
            creator: "Kesha",
            year: 2010,
            category: .vinyl,
            note: "LP · 14 tracks · dance-pop, electropop · Launch reference: US$25 · Current reference: US$35",
            colorA: "355C7D",
            colorB: "C06C84",
            imageName: "album_003"
        ),
        CollectibleItem(
            id: UUID(uuidString: "0A26BC6E-9F87-53E7-83F5-F444A09D0569")!,
            title: "New Jeans (1st EP)",
            creator: "NewJeans",
            year: 2022,
            category: .vinyl,
            note: "CD / Bag Version · 4 tracks · K-pop, Y2K pop · Launch reference: US$25 · Current reference: US$30",
            colorA: "355C7D",
            colorB: "C06C84",
            imageName: "album_004"
        ),
        CollectibleItem(
            id: UUID(uuidString: "1BFE5112-7C8D-55AF-A723-70B47A2F6155")!,
            title: "ODYSSEY",
            creator: "RIIZE",
            year: 2025,
            category: .vinyl,
            note: "CD (1st Studio Album) · 10 tracks · K-pop, dance-pop · Launch reference: US$25 · Current reference: US$28",
            colorA: "355C7D",
            colorB: "C06C84",
            imageName: "album_005"
        ),
        CollectibleItem(
            id: UUID(uuidString: "5F08E9C1-C9E3-52D7-9129-50E2DB136D6B")!,
            title: "eternal sunshine deluxe: brighter days ahead",
            creator: "Ariana Grande",
            year: 2025,
            category: .vinyl,
            note: "2LP Deluxe Edition · 22 tracks · pop, R&B · Launch reference: US$42 · Current reference: US$45",
            colorA: "355C7D",
            colorB: "C06C84",
            imageName: "album_006"
        ),
        CollectibleItem(
            id: UUID(uuidString: "CA858FB2-B30F-5D80-9A53-DF9133358412")!,
            title: "HELP EVER HURT NEVER",
            creator: "Fujii Kaze",
            year: 2020,
            category: .vinyl,
            note: "2LP · 11 tracks · J-pop, R&B, soul · Launch reference: US$40 · Current reference: US$65",
            colorA: "355C7D",
            colorB: "C06C84",
            imageName: "album_007"
        ),
        CollectibleItem(
            id: UUID(uuidString: "05633097-0353-597B-92E5-28CB74364566")!,
            title: "First Love",
            creator: "Hikaru Utada",
            year: 1999,
            category: .vinyl,
            note: "2LP / CD · 12 tracks · J-pop, R&B · Launch reference: US$35 · Current reference: US$55",
            colorA: "355C7D",
            colorB: "C06C84",
            imageName: "album_008"
        ),
        CollectibleItem(
            id: UUID(uuidString: "593D360B-0C59-5DC1-9560-98C4F8F9EB11")!,
            title: "The Rise and Fall of a Midwest Princess",
            creator: "Chappell Roan",
            year: 2023,
            category: .vinyl,
            note: "2LP · 14 tracks · pop, synth-pop · Launch reference: US$40 · Current reference: US$42",
            colorA: "355C7D",
            colorB: "C06C84",
            imageName: "album_009"
        ),
        CollectibleItem(
            id: UUID(uuidString: "610EB668-621A-572E-8E62-BD9901FE7C54")!,
            title: "MAYHEM",
            creator: "Lady Gaga",
            year: 2025,
            category: .vinyl,
            note: "LP · 14 tracks · pop, dance-pop · Launch reference: US$40 · Current reference: US$40",
            colorA: "355C7D",
            colorB: "C06C84",
            imageName: "album_010"
        ),
        CollectibleItem(
            id: UUID(uuidString: "5EDF3870-9517-55F9-8E22-F201C34C9267")!,
            title: "Josephine “Jo” March",
            creator: "SDGr Girl",
            year: 2016,
            category: .bjd,
            note: "Alias: Jo · Series: SDGr Girl · Launch price (pre-tax): ¥118,518 · Launch price (tax included): Approx. ¥128,000",
            colorA: "B08968",
            colorB: "6D597A",
            imageName: "bjd_001"
        ),
        CollectibleItem(
            id: UUID(uuidString: "CE611705-4AD9-5B54-9389-D3DDCA094334")!,
            title: "Hatsune Miku NT",
            creator: "Dollfie Dream",
            year: 2024,
            category: .bjd,
            note: "Series: Dollfie Dream · Launch price (pre-tax): ¥69,000 · Launch price (tax included): ¥75,900",
            colorA: "B08968",
            colorB: "6D597A",
            imageName: "bjd_002"
        ),
        CollectibleItem(
            id: UUID(uuidString: "D8FAF207-0B43-5A23-BFCA-EBD538FCB14E")!,
            title: "Suiseiseki",
            creator: "SD Girl",
            year: 2007,
            category: .bjd,
            note: "Series: SD Girl · Launch price (pre-tax): ¥92,000 · Launch price (tax included): ¥96,600",
            colorA: "B08968",
            colorB: "6D597A",
            imageName: "bjd_003"
        ),
        CollectibleItem(
            id: UUID(uuidString: "56452ECA-E5DD-547E-B010-F62E7FBB1E8B")!,
            title: "Charlotte",
            creator: "SD Girl",
            year: 2010,
            category: .bjd,
            note: "Alias: Standard Girl · Series: SD Girl · Launch price (pre-tax): ¥88,000 · Launch price (tax included): ¥92,400",
            colorA: "B08968",
            colorB: "6D597A",
            imageName: "bjd_004"
        ),
        CollectibleItem(
            id: UUID(uuidString: "547846F9-4E81-5389-88FA-FCDB5127289F")!,
            title: "Lieselotte",
            creator: "SD Girl",
            year: 2010,
            category: .bjd,
            note: "Alias: White Girl · Series: SD Girl · Launch price (pre-tax): ¥88,000 · Launch price (tax included): ¥92,400",
            colorA: "B08968",
            colorB: "6D597A",
            imageName: "bjd_005"
        ),
        CollectibleItem(
            id: UUID(uuidString: "58F3CDE6-9E1D-5F11-911C-C87B1F59C261")!,
            title: "Dear SD Nayu",
            creator: "Dear SD",
            year: 2022,
            category: .bjd,
            note: "Alias: Nayu · Series: Dear SD · Launch price (pre-tax): From ¥65,000 · Launch price (tax included): From ¥71,500",
            colorA: "B08968",
            colorB: "6D597A",
            imageName: "bjd_006"
        ),
        CollectibleItem(
            id: UUID(uuidString: "0CB0643A-68BF-5459-8889-7B48ECAB25FD")!,
            title: "Mina",
            creator: "Super Dollfie Cute",
            year: 2014,
            category: .bjd,
            note: "Series: Super Dollfie Cute · Launch price (pre-tax): ¥56,000 · Launch price (tax included): Approx. ¥60,480",
            colorA: "B08968",
            colorB: "6D597A",
            imageName: "bjd_007"
        ),
        CollectibleItem(
            id: UUID(uuidString: "3AA49C75-EBF8-503C-A6EB-8E51AA4417CD")!,
            title: "Mako",
            creator: "Super Dollfie Midi",
            year: 2014,
            category: .bjd,
            note: "Series: Super Dollfie Midi · Launch price (pre-tax): ¥40,000 · Launch price (tax included): ¥43,200",
            colorA: "B08968",
            colorB: "6D597A",
            imageName: "bjd_008"
        ),
        CollectibleItem(
            id: UUID(uuidString: "43692834-8CCC-55E5-96CC-03C0DBEA77E8")!,
            title: "Tae",
            creator: "SD Girl",
            year: 2008,
            category: .bjd,
            note: "Alias: Tae / Ichikura Open-Eyed Version · Series: SD Girl · Launch price (pre-tax): ¥79,000 · Launch price (tax included): ¥89,250",
            colorA: "B08968",
            colorB: "6D597A",
            imageName: "bjd_009"
        ),
        CollectibleItem(
            id: UUID(uuidString: "A1570EAC-9EF2-5102-BE29-E391B13911A3")!,
            title: "Yume-Tenshi Kasumi",
            creator: "SDGr Yume-Tenshi",
            year: 2014,
            category: .bjd,
            note: "Alias: Kasumi · Series: SDGr Yume-Tenshi · Launch price (pre-tax): From ¥220,000 · Launch price (tax included): From ¥242,000",
            colorA: "B08968",
            colorB: "6D597A",
            imageName: "bjd_010"
        ),
        CollectibleItem(
            id: UUID(uuidString: "7B89E12D-E43B-5518-B8EC-87429A6CDB84")!,
            title: "&TEAM Photocard 01",
            creator: "&TEAM",
            year: nil,
            category: .photocard,
            note: "Offer price: US$300 · Status: Open · BTL lottery photocard from the HMV Tokyo K & JO unit talk and photocard hand-off event; limited edition. · Source: Spotted",
            colorA: "4E8098",
            colorB: "90C2E7",
            imageName: "photocard_001"
        ),
        CollectibleItem(
            id: UUID(uuidString: "500AF233-5716-51C6-8FD7-BBD58FAFE354")!,
            title: "&TEAM Photocard 02",
            creator: "&TEAM",
            year: nil,
            category: .photocard,
            note: "Offer price: US$8 · Status: Open · Willing to raise the price if necessary. · Source: Spotted",
            colorA: "4E8098",
            colorB: "90C2E7",
            imageName: "photocard_002"
        ),
        CollectibleItem(
            id: UUID(uuidString: "AFA6E2FD-B7E7-56A4-BF07-489B20A91DDC")!,
            title: "&TEAM Photocard 03",
            creator: "&TEAM",
            year: nil,
            category: .photocard,
            note: "Offer price: US$70 · Status: Open · Can pay more if needed. · Source: Spotted",
            colorA: "4E8098",
            colorB: "90C2E7",
            imageName: "photocard_003"
        ),
        CollectibleItem(
            id: UUID(uuidString: "03A2B7F2-9764-5F3C-AF92-72EF00BA2871")!,
            title: "&TEAM Photocard 04",
            creator: "&TEAM",
            year: nil,
            category: .photocard,
            note: "Offer price: US$77 · Status: Open · Can pay more if needed. · Source: Spotted",
            colorA: "4E8098",
            colorB: "90C2E7",
            imageName: "photocard_004"
        ),
        CollectibleItem(
            id: UUID(uuidString: "2E4F7381-2051-58CF-9749-F8170357E169")!,
            title: "Stray Kids Photocard 05",
            creator: "Stray Kids",
            year: nil,
            category: .photocard,
            note: "Offer price: US$26 · Status: Open · Source: Spotted",
            colorA: "4E8098",
            colorB: "90C2E7",
            imageName: "photocard_005"
        ),
        CollectibleItem(
            id: UUID(uuidString: "709CD219-7AB6-557C-9BFF-4A4CB2912C49")!,
            title: "Stray Kids Photocard 06",
            creator: "Stray Kids",
            year: nil,
            category: .photocard,
            note: "Offer price: US$5 · Status: Open · Open to trading the double-sided Hyunjin version; please let me know. · Source: Spotted",
            colorA: "4E8098",
            colorB: "90C2E7",
            imageName: "photocard_006"
        ),
        CollectibleItem(
            id: UUID(uuidString: "E13A3C10-0248-5D59-822E-E8A8EC38CF31")!,
            title: "BOYNEXTDOOR Photocard 07",
            creator: "BOYNEXTDOOR",
            year: nil,
            category: .photocard,
            note: "Offer price: US$5 · Status: Open · Source: Spotted",
            colorA: "4E8098",
            colorB: "90C2E7",
            imageName: "photocard_007"
        ),
        CollectibleItem(
            id: UUID(uuidString: "ECB3C612-08F7-5E25-A965-76858CBE173F")!,
            title: "BTS Photocard 08",
            creator: "BTS",
            year: nil,
            category: .photocard,
            note: "Offer price: US$35 · Status: Open · Please hold it or allow installment payments; this is intended as a birthday gift. · Source: Spotted",
            colorA: "4E8098",
            colorB: "90C2E7",
            imageName: "photocard_008"
        ),
        CollectibleItem(
            id: UUID(uuidString: "881E2E3E-4CE9-536B-8021-7B931AA9786F")!,
            title: "LNGSHOT Photocard 09",
            creator: "LNGSHOT",
            year: nil,
            category: .photocard,
            note: "Offer price: US$12 · Status: Open · Source: Spotted",
            colorA: "4E8098",
            colorB: "90C2E7",
            imageName: "photocard_009"
        ),
        CollectibleItem(
            id: UUID(uuidString: "8B6158D2-FA60-5381-B676-6E70AAA75785")!,
            title: "ENHYPEN Photocard 10",
            creator: "ENHYPEN",
            year: nil,
            category: .photocard,
            note: "Offer price: US$30 · Status: Open · Source: Spotted",
            colorA: "4E8098",
            colorB: "90C2E7",
            imageName: "photocard_010"
        ),
        CollectibleItem(
            id: UUID(uuidString: "F8A52676-7CB5-5ADD-8185-57E9FE7D78E2")!,
            title: "Dune",
            creator: "",
            year: 2021,
            category: .poster,
            note: "United States · US Double-Sided Theatrical Poster · double-sided, theatrical, US · Poster release year: 2021; Studio/distributor: Warner Bros. Pictures; Current reference price: US$40.00 (eBay)",
            colorA: "6B705C",
            colorB: "CB997E",
            imageName: "movie_poster_001"
        ),
        CollectibleItem(
            id: UUID(uuidString: "2469CD03-F725-5BB3-8314-D6617CAE1770")!,
            title: "Harry Potter and the Sorcerer’s Stone",
            creator: "",
            year: 2001,
            category: .poster,
            note: "United States · US Teaser Poster · teaser, US · Poster release year: 2001; Studio/distributor: Warner Bros. Pictures; Current reference price: US$175.00 (Posteritati Movie Poster Gallery)",
            colorA: "6B705C",
            colorB: "CB997E",
            imageName: "movie_poster_002"
        ),
        CollectibleItem(
            id: UUID(uuidString: "ED277C60-87FD-513D-BA0C-9B3B19207766")!,
            title: "Blade Runner",
            creator: "John Alvin",
            year: 1982,
            category: .poster,
            note: "United States · John Alvin Illustrated US Original Poster · Designer: John Alvin · original, illustrated, US · Poster release year: 1982; Studio/distributor: Warner Bros. Pictures; Current reference price: US$1,349.99 (Posteritati Movie Poster Gallery)",
            colorA: "6B705C",
            colorB: "CB997E",
            imageName: "movie_poster_003"
        ),
        CollectibleItem(
            id: UUID(uuidString: "87892366-6A73-5A99-A44F-E17A0CAEE501")!,
            title: "The Odyssey",
            creator: "",
            year: 2026,
            category: .poster,
            note: "United States · Nolan Version US Teaser Poster · teaser, US · Poster release year: 2026; Studio/distributor: Universal Pictures; Current reference price: £300.00 (At The Movies Posters)",
            colorA: "6B705C",
            colorB: "CB997E",
            imageName: "movie_poster_004"
        ),
        CollectibleItem(
            id: UUID(uuidString: "E9367DCD-44B3-58D2-9033-5F846D0EC126")!,
            title: "Spider-Man: Brand New Day",
            creator: "",
            year: 2026,
            category: .poster,
            note: "United States · US Double-Sided Theatrical Poster · double-sided, theatrical, US · Poster release year: 2026; Distributor: Sony Pictures Releasing; Current reference price: US$149.99 (movieposters.com)",
            colorA: "6B705C",
            colorB: "CB997E",
            imageName: "movie_poster_005"
        ),
        CollectibleItem(
            id: UUID(uuidString: "D3693804-417C-55D4-B6AA-426A775DC1D8")!,
            title: "Better Days",
            creator: "Huang Hai (Zhuye Culture)",
            year: 2019,
            category: .poster,
            note: "Mainland China · China Official Poster (Huang Hai Design Series) · Designer: Huang Hai (Zhuye Culture) · official, Huang Hai design, China · Poster release year: 2019; Studios/distributors: Lian Ray Pictures, Taopiaopiao, Maoyan Weiying, Huaxia Film Distribution; Current reference price: No verifiable original-edition listing found (Zhihu)",
            colorA: "6B705C",
            colorB: "CB997E",
            imageName: "movie_poster_006"
        ),
        CollectibleItem(
            id: UUID(uuidString: "19D1A576-657F-5703-BEA6-8E5194CC30A9")!,
            title: "Zootopia",
            creator: "",
            year: 2016,
            category: .poster,
            note: "United States · “Welcome to the Urban Jungle” US Double-Sided Poster · double-sided, US · Poster release year: 2016; Studio/distributor: Walt Disney Studios Motion Pictures; Current reference price: US$44.99 (eBay)",
            colorA: "6B705C",
            colorB: "CB997E",
            imageName: "movie_poster_007"
        ),
        CollectibleItem(
            id: UUID(uuidString: "E34E7F0D-DCE3-5EAE-9501-C62A8F5EAEE3")!,
            title: "Resurrection",
            creator: "Brandon Schaefer",
            year: 2025,
            category: .poster,
            note: "United States · US Original Theatrical Poster · Designer: Brandon Schaefer · original, theatrical, US · Poster release year: 2025; Studios/distributors: Huace Pictures (China), Janus Films (North America); Current reference price: US$95.00 (Posteritati Movie Poster Gallery)",
            colorA: "6B705C",
            colorB: "CB997E",
            imageName: "movie_poster_008"
        ),
        CollectibleItem(
            id: UUID(uuidString: "19B4F10F-78C5-5D33-BAA4-29F58A1FB311")!,
            title: "F1 The Movie",
            creator: "",
            year: 2025,
            category: .poster,
            note: "United States · US Double-Sided Theatrical Poster · double-sided, theatrical, US · Poster release year: 2025; Studios/distributors: Apple Original Films, Warner Bros. Pictures; Current reference price: £175.00 (Famous Movie Posters)",
            colorA: "6B705C",
            colorB: "CB997E",
            imageName: "movie_poster_009"
        ),
        CollectibleItem(
            id: UUID(uuidString: "8CD237ED-038B-5C6C-90D4-B7DA89251671")!,
            title: "La La Land",
            creator: "",
            year: 2016,
            category: .poster,
            note: "United States · “La La Hand” US Teaser Poster · teaser, US · Poster release year: 2016; Studio/distributor: Summit Entertainment, distributed by Lionsgate; Current reference price: US$495.00 (Posteritati Movie Poster Gallery)",
            colorA: "6B705C",
            colorB: "CB997E",
            imageName: "movie_poster_010"
        ),
    ]
}

extension SeedData {
    /// Demo only: the sample objects have no real acquisition date, so they
    /// get fixed example dates spread over May–October 2026 to fill the
    /// collection calendar. User objects record their real date when added.
    static let itemsWithDemoDates: [CollectibleItem] = items.enumerated().map { index, item in
        var item = item
        let components = DateComponents(
            year: 2026,
            month: 5 + index % 6,
            day: 1 + (index * 7) % 27,
            hour: 12
        )
        item.addedOn = Calendar.current.date(from: components)
        return item
    }
}
