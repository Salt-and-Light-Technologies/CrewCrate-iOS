import Foundation

/// Fictional SMS transcripts for the online campaign preview only.
enum DemoCampaignMessageFixtures {
    static let contacts: [DemoContactedLead] = [
        DemoContactedLead(id: 1, name: "Logan Carter", phone: "+1 (202) 555-0101", outcome: "Inspection requested · Handed to sales", messages: [
            .init(id: 1, text: "Hi Logan, I'm Emma, John Doe Roofing's AI assistant. You previously asked us about a roof repair. Do you still need help? We're offering a free roof inspection and 10% off a qualifying repair. Reply STOP to opt out.", time: "9:00 AM", isOutbound: true),
            .init(id: 2, text: "Yes, we still have a leak around the chimney when it rains. Is the inspection really free?", time: "9:04 AM", isOutbound: false),
            .init(id: 3, text: "Yes, the inspection is free. Our roofing team can check the leak and explain repair options. Are you the homeowner, and what ZIP code is the property in?", time: "9:04 AM", isOutbound: true),
            .init(id: 4, text: "I'm the homeowner. It's in 63109. I'd like someone to take a look this week.", time: "9:06 AM", isOutbound: false),
            .init(id: 5, text: "Thanks, Logan. I'll send your inspection request and chimney leak details to our sales team. They'll confirm service availability and a time with you. They'll also explain whether the repair qualifies for the 10% offer.", time: "9:06 AM", isOutbound: true),
            .init(id: 6, text: "Great, afternoons are best. Thank you!", time: "9:07 AM", isOutbound: false)
        ]),
        DemoContactedLead(id: 2, name: "Drew Mitchell", phone: "+1 (202) 555-0102", outcome: "Interested · Awaiting response", messages: [
            .init(id: 1, text: "Hi Drew, I'm Emma, John Doe Roofing's AI assistant. Following up on your earlier roofing enquiry: we're offering a free roof inspection and 10% off a qualifying repair. Would you like to explore that? Reply STOP to opt out.", time: "9:10 AM", isOutbound: true),
            .init(id: 2, text: "A few shingles came off in the last storm. Does the discount apply to a full replacement too?", time: "9:13 AM", isOutbound: false),
            .init(id: 3, text: "The offer is for qualifying repairs. I can't promise a discount on a full replacement, but our team can explain the options after a free inspection. Are you the homeowner, and what ZIP code is the property in?", time: "9:13 AM", isOutbound: true),
            .init(id: 4, text: "Yes, 63116. I want to compare repair and replacement costs before deciding.", time: "9:15 AM", isOutbound: false),
            .init(id: 5, text: "That makes sense. Would you like me to ask our sales team to contact you about a free inspection and discuss both options?", time: "9:15 AM", isOutbound: true)
        ]),
        DemoContactedLead(id: 3, name: "Reese Brooks", phone: "+1 (202) 555-0103", outcome: "Opted out · Further outreach stopped", messages: [
            .init(id: 1, text: "Hi Reese, I'm Emma, John Doe Roofing's AI assistant. You previously requested a roofing quote. Do you still need help? We have a free roof inspection and 10% off a qualifying repair. Reply STOP to opt out.", time: "9:20 AM", isOutbound: true),
            .init(id: 2, text: "We already had it repaired. Please stop texting me.", time: "9:22 AM", isOutbound: false),
            .init(id: 3, text: "Understood. You've been opted out and won't receive further campaign texts from us.", time: "9:22 AM", isOutbound: true)
        ])
    ]
}
