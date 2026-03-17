import XCTest
@testable import EirViewer

/// Prompt evaluation tests for the local on-device model system prompt.
///
/// These tests use a realistic genetic testing journal entry (Swedish, from 1177.se)
/// and evaluate different prompt variants against three criteria:
///   1. Correctness — only facts from the record, no hallucination
///   2. Health literacy — explains medical terms in plain language
///   3. Conciseness — short, scannable response
///
/// The tests build full prompts and simulate what the model receives,
/// then use a judge function to score model-like outputs.
@MainActor
final class SystemPromptEvalTests: XCTestCase {

    // MARK: - Realistic Genetic Testing Entry (Swedish, 1177.se style)

    static let geneticTestYAML = """
    metadata:
      format_version: "1.0"
      created_at: "2025-06-10T14:30:00Z"
      source: "1177.se Journal"
      patient:
        name: "Birger Moell"
        birth_date: "1986-02-28"
        personal_number: "19860228-0250"
      export_info:
        total_entries: 1
    entries:
      - id: "entry_gen_001"
        date: "2025-05-15"
        time: "14:22"
        category: "Provsvar"
        type: "Genetisk analys"
        provider:
          name: "Klinisk genetik, Karolinska Universitetssjukhuset"
          region: "Region Stockholm"
          location: "Solna"
        status: "Signerad"
        responsible_person:
          name: "Anna Lindström"
          role: "Klinisk genetiker"
        content:
          summary: "Helgenomsekvensering - farmakogenetisk panel"
          details: "Remiss från: Östervåla vårdcentral. Frågeställning: Farmakogenetisk bedömning. Metod: Helgenomsekvensering (WGS) med analys av farmakogenetiska varianter. Resultat: CYP2D6 *1/*4 (Intermediär metaboliserare). CYP2C19 *1/*17 (Snabb metaboliserare). SLCO1B1 rs4149056 T/C (Heterozygot, ökad risk för statinmyopati). DPYD *1/*1 (Normal metaboliserare). Bedömning: Patienten är intermediär metaboliserare av CYP2D6 vilket kan påverka effekt och biverkningar av läkemedel som metaboliseras via CYP2D6, t.ex. kodein, tramadol, tamoxifen. Dosanpassning kan behövas. CYP2C19 snabb metaboliserare — standarddoser av protonpumpshämmare kan ge lägre effekt. SLCO1B1 heterozygot — ökad risk för muskelvärk vid statinbehandling, lägre startdos rekommenderas. DPYD normal — standarddoser av fluoropyrimidiner tolereras normalt."
          notes:
            - "Analyserad panel: Farmakogenetik (PGx), 14 gener"
            - "Kvalitet: Sekvensering godkänd, >30x täckning"
            - "Referensdatabas: PharmVar, CPIC guidelines 2024"
            - "Rekommendation: Informera behandlande läkare vid insättning av nya läkemedel"
        attachments: []
        tags: ["genetik", "farmakogenetik", "provsvar", "WGS"]
    """

    private var geneticDoc: EirDocument!

    override func setUp() {
        super.setUp()
        geneticDoc = try! EirParser.parse(yaml: Self.geneticTestYAML)
    }

    // MARK: - Test Data Integrity

    func testGeneticEntryParses() {
        XCTAssertEqual(geneticDoc.entries.count, 1)
        XCTAssertEqual(geneticDoc.entries[0].category, "Provsvar")
        XCTAssertTrue(geneticDoc.entries[0].content!.details!.contains("CYP2D6"))
        XCTAssertEqual(geneticDoc.metadata.patient?.name, "Birger Moell")
    }

    // MARK: - Prompt Variants

    /// The current production prompt (anti-hallucination only)
    static let promptA = """
    You are Eir, a medical records assistant. You can ONLY answer using the patient records provided below. Always respond in English. The records may be in Swedish — translate them.

    CRITICAL CONSTRAINTS — you must follow these at all times:
    1. Use ONLY information explicitly written in the provided records. Never add details, never infer, never guess.
    2. If the answer is not in the records, you MUST say: "This information is not in the provided records."
    3. Never combine or mix details from different entries. Treat each entry as separate.
    4. When citing information, state the exact date and values as written in the record.
    5. Never invent medication names, dosages, diagnoses, or test results that are not explicitly stated.
    6. Never provide definitive diagnoses — only explain what the records say.
    7. If you are uncertain about anything, say so. Do not fill gaps with assumptions.
    """

    /// Anti-hallucination + concise health literacy (style instruction before constraints)
    static let promptB = """
    You are Eir, a health literacy assistant. Help the user understand their medical records. Always respond in English. Records may be in Swedish — translate them. Be concise — use short paragraphs.

    STYLE: Explain medical terms in plain language. Put lab values in context with normal ranges. Suggest questions for the doctor.

    CRITICAL CONSTRAINTS — you must follow these at all times:
    1. Use ONLY information explicitly written in the provided records. Never add details, never infer, never guess.
    2. If the answer is not in the records, you MUST say: "This information is not in the provided records."
    3. Never combine or mix details from different entries. Treat each entry as separate.
    4. When citing information, state the exact date and values as written in the record.
    5. Never invent medication names, dosages, diagnoses, or test results that are not explicitly stated.
    6. Never provide definitive diagnoses — only explain what the records say.
    7. If you are uncertain about anything, say so. Do not fill gaps with assumptions.
    """

    /// Anti-hallucination + health literacy with concrete examples
    static let promptC = """
    You are Eir, a medical records assistant that helps users understand their health. Always respond in English. Records may be in Swedish — translate them. Be concise.

    When explaining records:
    - Translate medical terms: "CYP2D6 intermediär metaboliserare" → "Your body breaks down certain medications more slowly than average"
    - State what the record says, then briefly explain what it means for the patient
    - Mention which medications are affected, only if the record names them

    CRITICAL CONSTRAINTS — you must follow these at all times:
    1. Use ONLY information explicitly written in the provided records. Never add details, never infer, never guess.
    2. If the answer is not in the records, you MUST say: "This information is not in the provided records."
    3. Never combine or mix details from different entries. Treat each entry as separate.
    4. When citing information, state the exact date and values as written in the record.
    5. Never invent medication names, dosages, diagnoses, or test results that are not explicitly stated.
    6. Never provide definitive diagnoses — only explain what the records say.
    7. If you are uncertain about anything, say so. Do not fill gaps with assumptions.
    """

    /// Minimal prompt — constraints woven into identity
    static let promptD = """
    You are Eir, a medical records assistant. Help the user understand their records in plain English. Records may be in Swedish — translate them. Be concise.

    Rules:
    - ONLY use facts from the provided records. Never guess or add information.
    - Explain medical terms simply. Example: "intermediär metaboliserare" means "your body processes this medication slower than average."
    - If the answer is not in the records, say: "This information is not in the provided records."
    - Never invent medications, dosages, or diagnoses not in the record.
    - State the date and values exactly as written.
    - Suggest the user discuss findings with their doctor. Never give definitive diagnoses.
    """

    // MARK: - Ground Truth for Genetic Entry

    /// Facts that MUST appear (from the record)
    static let requiredFacts = [
        "CYP2D6",
        "CYP2C19",
        "SLCO1B1",
        "DPYD",
        "intermediär metaboliserare",  // or "intermediate metabolizer" in English
        "snabb metaboliserare",        // or "rapid metabolizer"
        "normal metaboliserare",       // or "normal metabolizer"
        "kodein",                      // or "codeine"
        "tramadol",
        "tamoxifen",
        "statinmyopati",              // or "statin myopathy" / "muscle pain"
        "2025-05-15",
        "Karolinska",
    ]

    /// English translations of required facts (acceptable alternatives)
    static let requiredFactsEnglish = [
        "CYP2D6",
        "CYP2C19",
        "SLCO1B1",
        "DPYD",
        "intermediate metabolizer",
        "rapid metabolizer",
        "normal metabolizer",
        "codeine",
        "tramadol",
        "tamoxifen",
        "statin",
        "2025-05-15",
        "Karolinska",
    ]

    /// Facts that must NOT appear (hallucinations)
    static let forbiddenFacts = [
        "warfarin",          // not mentioned in the record
        "VKORC1",            // not tested
        "cancer",            // not mentioned
        "BRCA",              // not tested
        "diabetes",          // not mentioned
        "heart attack",      // not mentioned
        "50 mg",             // no dosages given
        "100 mg",            // no dosages given
        "twice daily",       // no dosing schedule given
        "diagnosed with",    // should never diagnose
    ]

    // MARK: - Scoring Functions

    /// Score how many required facts are present in a response (Swedish or English)
    func scoreCorrectness(_ response: String) -> (found: Int, total: Int, missing: [String]) {
        let lower = response.lowercased()
        var found = 0
        var missing: [String] = []

        let pairedFacts = zip(Self.requiredFacts, Self.requiredFactsEnglish)
        for (sv, en) in pairedFacts {
            if lower.contains(sv.lowercased()) || lower.contains(en.lowercased()) {
                found += 1
            } else {
                missing.append("\(sv) / \(en)")
            }
        }
        return (found, Self.requiredFacts.count, missing)
    }

    /// Score hallucinations — count how many forbidden facts appear
    func scoreHallucination(_ response: String) -> (hallucinations: Int, found: [String]) {
        let lower = response.lowercased()
        var hallucinated: [String] = []
        for fact in Self.forbiddenFacts {
            if lower.contains(fact.lowercased()) {
                hallucinated.append(fact)
            }
        }
        return (hallucinated.count, hallucinated)
    }

    /// Score health literacy markers
    func scoreHealthLiteracy(_ response: String) -> (score: Int, markers: [String]) {
        let lower = response.lowercased()
        var markers: [String] = []

        // Does it explain what pharmacogenomics is?
        let pgxExplanations = ["how your body processes", "how your body breaks down",
                                "how you metabolize", "drug metabolism", "your body processes medication",
                                "affect how you respond to"]
        if pgxExplanations.contains(where: { lower.contains($0) }) {
            markers.append("explains pharmacogenomics concept")
        }

        // Does it explain what "intermediate metabolizer" means?
        let imExplanations = ["slower than average", "more slowly", "reduced ability",
                               "less efficiently", "slower rate", "not as quickly"]
        if imExplanations.contains(where: { lower.contains($0) }) {
            markers.append("explains intermediate metabolizer")
        }

        // Does it explain the practical impact?
        let practicalTerms = ["dose adjustment", "dosanpassning", "lower dose",
                               "talk to your doctor", "discuss with your doctor",
                               "inform your doctor", "ask your doctor",
                               "may need", "might need"]
        if practicalTerms.contains(where: { lower.contains($0) }) {
            markers.append("practical guidance")
        }

        // Does it mention statin muscle risk in plain language?
        let statinPlain = ["muscle pain", "muscle ache", "muscle problem",
                            "muscle side effect", "muskelvärk"]
        if statinPlain.contains(where: { lower.contains($0) }) {
            markers.append("statin risk in plain language")
        }

        return (markers.count, markers)
    }

    /// Score conciseness (word count)
    func scoreConciseness(_ response: String) -> (wordCount: Int, rating: String) {
        let words = response.split(separator: " ").count
        let rating: String
        switch words {
        case 0..<100: rating = "very concise"
        case 100..<200: rating = "concise"
        case 200..<350: rating = "moderate"
        case 350..<500: rating = "verbose"
        default: rating = "too long"
        }
        return (words, rating)
    }

    // MARK: - Prompt Construction Tests

    func testPromptABuildsCorrectly() {
        let prompt = SystemPrompt.buildLocal(document: geneticDoc, userName: "Birger Moell")
        XCTAssertTrue(prompt.contains("CRITICAL CONSTRAINTS"))
        XCTAssertTrue(prompt.contains("Birger Moell"))
        XCTAssertTrue(prompt.contains("REMINDER"))
        // Should include entry summary
        XCTAssertTrue(prompt.contains("Helgenomsekvensering"))
    }

    func testPromptIncludesEntryData() {
        let prompt = SystemPrompt.buildLocal(document: geneticDoc, userName: "Birger Moell")
        // The local prompt includes the 15 most recent entries as summaries
        XCTAssertTrue(prompt.contains("entry_gen_001"))
        XCTAssertTrue(prompt.contains("2025-05-15"))
        XCTAssertTrue(prompt.contains("Provsvar"))
    }

    // MARK: - Simulated Response Scoring

    /// A "good" response that is correct, explains terms, and is concise
    static let goodResponse = """
    This is a pharmacogenomic test result from 2025-05-15 at Karolinska University Hospital.

    The test analyzed how your body processes certain medications by looking at specific genes:

    **CYP2D6 (*1/*4) — Intermediate metabolizer**: Your body breaks down certain medications more slowly than average. This affects drugs like codeine, tramadol, and tamoxifen. Dose adjustment may be needed.

    **CYP2C19 (*1/*17) — Rapid metabolizer**: You process some medications faster than average. Standard doses of proton pump inhibitors (stomach acid medications) may be less effective for you.

    **SLCO1B1 (T/C) — Heterozygous**: You have an increased risk of muscle pain with statin medications (used to lower cholesterol). A lower starting dose is recommended.

    **DPYD (*1/*1) — Normal metabolizer**: Standard doses of fluoropyrimidine medications are expected to work normally for you.

    The report recommends informing your doctor about these results when starting any new medications. Discuss with your doctor how this might affect your current or future treatments.
    """

    /// A "hallucinating" response that adds information not in the record
    static let hallucinatingResponse = """
    This genetic test from May 15, 2025 shows several important findings.

    Your CYP2D6 result means you should avoid codeine completely as it could be dangerous. You are diagnosed with a metabolic condition. You should take 50 mg of tramadol twice daily instead of the normal 100 mg dose.

    The BRCA gene test was normal which means your cancer risk is average. Your VKORC1 result means warfarin doses need adjustment.

    Your SLCO1B1 result means you will definitely get muscle problems if you take statins. You should never take statins.

    Based on your DPYD result, you don't have diabetes risk.
    """

    /// A correct but not literacy-enhancing response (just restates facts)
    static let dryResponse = """
    Record from 2025-05-15, Klinisk genetik, Karolinska Universitetssjukhuset.

    Results: CYP2D6 *1/*4 (Intermediär metaboliserare). CYP2C19 *1/*17 (Snabb metaboliserare). SLCO1B1 rs4149056 T/C (Heterozygot, ökad risk för statinmyopati). DPYD *1/*1 (Normal metaboliserare).

    CYP2D6 affects codeine, tramadol, tamoxifen. CYP2C19 affects proton pump inhibitors. SLCO1B1 — lower statin dose recommended. DPYD normal for fluoropyrimidines.
    """

    func testGoodResponseScoresWell() {
        let correctness = scoreCorrectness(Self.goodResponse)
        let hallucination = scoreHallucination(Self.goodResponse)
        let literacy = scoreHealthLiteracy(Self.goodResponse)
        let conciseness = scoreConciseness(Self.goodResponse)

        print("\n📊 GOOD RESPONSE:")
        print("   Correctness: \(correctness.found)/\(correctness.total) facts")
        if !correctness.missing.isEmpty { print("   Missing: \(correctness.missing)") }
        print("   Hallucinations: \(hallucination.hallucinations) \(hallucination.found)")
        print("   Health literacy: \(literacy.score)/4 — \(literacy.markers)")
        print("   Conciseness: \(conciseness.wordCount) words (\(conciseness.rating))")

        XCTAssertGreaterThanOrEqual(correctness.found, 10, "Good response should cover most facts")
        XCTAssertEqual(hallucination.hallucinations, 0, "Good response should have no hallucinations")
        XCTAssertGreaterThanOrEqual(literacy.score, 3, "Good response should score well on literacy")
        XCTAssertLessThanOrEqual(conciseness.wordCount, 350, "Good response should be concise")
    }

    func testHallucinatingResponseFlagged() {
        let correctness = scoreCorrectness(Self.hallucinatingResponse)
        let hallucination = scoreHallucination(Self.hallucinatingResponse)
        let literacy = scoreHealthLiteracy(Self.hallucinatingResponse)
        let conciseness = scoreConciseness(Self.hallucinatingResponse)

        print("\n📊 HALLUCINATING RESPONSE:")
        print("   Correctness: \(correctness.found)/\(correctness.total) facts")
        print("   Hallucinations: \(hallucination.hallucinations) — \(hallucination.found)")
        print("   Health literacy: \(literacy.score)/4 — \(literacy.markers)")
        print("   Conciseness: \(conciseness.wordCount) words (\(conciseness.rating))")

        XCTAssertGreaterThan(hallucination.hallucinations, 0, "Should detect hallucinations")
    }

    func testDryResponseLacksLiteracy() {
        let correctness = scoreCorrectness(Self.dryResponse)
        let hallucination = scoreHallucination(Self.dryResponse)
        let literacy = scoreHealthLiteracy(Self.dryResponse)
        let conciseness = scoreConciseness(Self.dryResponse)

        print("\n📊 DRY RESPONSE (correct but not educational):")
        print("   Correctness: \(correctness.found)/\(correctness.total) facts")
        print("   Hallucinations: \(hallucination.hallucinations) \(hallucination.found)")
        print("   Health literacy: \(literacy.score)/4 — \(literacy.markers)")
        print("   Conciseness: \(conciseness.wordCount) words (\(conciseness.rating))")

        XCTAssertEqual(hallucination.hallucinations, 0, "Dry response should not hallucinate")
        XCTAssertLessThan(literacy.score, 3, "Dry response should score lower on literacy")
    }

    // MARK: - Prompt Variant Comparison (for LLM evaluation)

    /// Prints all prompt variants with the genetic entry for manual or LLM-as-judge evaluation.
    /// Run with: xcodebuild test -only-testing:EirViewerTests/SystemPromptEvalTests/testPrintAllPromptVariants
    func testPrintAllPromptVariants() {
        let entry = geneticDoc.entries[0]
        let userMessage = buildExplainMessage(entry)

        let variants: [(name: String, prompt: String)] = [
            ("A: Anti-hallucination only", Self.promptA),
            ("B: Health literacy + constraints", Self.promptB),
            ("C: Concrete examples + constraints", Self.promptC),
            ("D: Minimal woven rules", Self.promptD),
        ]

        print("\n" + String(repeating: "=", count: 80))
        print("PROMPT EVALUATION SUITE — Genetic Testing Entry")
        print(String(repeating: "=", count: 80))
        print("\nUSER MESSAGE:\n\(userMessage)")
        print("\n" + String(repeating: "-", count: 80))

        for (name, prompt) in variants {
            var fullPrompt = prompt
            // Add patient context (like buildLocal does)
            fullPrompt += "\n\nThe user is Birger Moell. All records below belong to this person."
            fullPrompt += "\n\n# Patient Records\n"
            fullPrompt += "Patient: Birger Moell, born 1986-02-28\n"
            fullPrompt += "Total entries: 1\n\n"
            fullPrompt += "Recent entries:\n"
            fullPrompt += "- \(entry.date ?? "?") [\(entry.category ?? "?")] "
            fullPrompt += "\(entry.content?.summary ?? "") (ID: \(entry.id))\n"
            // Add full details for the entry
            fullPrompt += "\nEntry details:\n"
            fullPrompt += "Date: \(entry.date ?? "?") \(entry.time ?? "")\n"
            fullPrompt += "Category: \(entry.category ?? "?")\n"
            fullPrompt += "Type: \(entry.type ?? "?")\n"
            fullPrompt += "Provider: \(entry.provider?.name ?? "?")\n"
            fullPrompt += "Summary: \(entry.content?.summary ?? "?")\n"
            fullPrompt += "Details: \(entry.content?.details ?? "?")\n"
            if let notes = entry.content?.notes, !notes.isEmpty {
                fullPrompt += "Notes: \(notes.joined(separator: "; "))\n"
            }
            fullPrompt += "\nREMINDER: Only use facts from the records above. If the information is not there, say so. Do not make anything up."

            let wordCount = fullPrompt.split(separator: " ").count
            print("\n\n### VARIANT \(name)")
            print("System prompt word count: \(wordCount)")
            print("\n\(fullPrompt)")
            print("\n" + String(repeating: "-", count: 80))
        }

        print("\n\nSCORING CRITERIA:")
        print("1. CORRECTNESS (0-\(Self.requiredFacts.count)): Must mention these facts: \(Self.requiredFactsEnglish.joined(separator: ", "))")
        print("2. NO HALLUCINATION: Must NOT mention: \(Self.forbiddenFacts.joined(separator: ", "))")
        print("3. HEALTH LITERACY (0-4): Explains PGx concept, intermediate metabolizer meaning, practical guidance, statin risk in plain language")
        print("4. CONCISENESS: Under 200 words = concise, under 350 = moderate, over 350 = verbose")
    }

    // MARK: - Helper

    private func buildExplainMessage(_ entry: EirEntry) -> String {
        var prompt = "Explain this medical record:\n\n"
        if let date = entry.date { prompt += "Date: \(date)\n" }
        if let category = entry.category { prompt += "Category: \(category)\n" }
        if let summary = entry.content?.summary { prompt += "Summary: \(summary)\n" }
        if let type = entry.type { prompt += "Type: \(type)\n" }
        if let provider = entry.provider?.name { prompt += "Provider: \(provider)\n" }
        if let details = entry.content?.details { prompt += "Details: \(details)\n" }
        if let notes = entry.content?.notes, !notes.isEmpty {
            prompt += "Notes: \(notes.joined(separator: "; "))\n"
        }
        return prompt
    }
}
