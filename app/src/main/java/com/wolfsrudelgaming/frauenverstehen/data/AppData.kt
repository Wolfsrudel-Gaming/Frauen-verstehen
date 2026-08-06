package com.wolfsrudelgaming.frauenverstehen.data

import androidx.compose.ui.graphics.Color

data class Uebersetzung(
    val wasSieSagt: String,
    val wasSieMeint: String,
    val emoji: String,
    val tipp: String
)

data class Stimmung(
    val name: String,
    val emoji: String,
    val beschreibung: String,
    val signale: List<String>,
    val wasZuTun: String,
    val farbe: Color
)

data class Tipp(
    val titel: String,
    val inhalt: String,
    val icon: String,
    val kategorie: String
)

data class QuizFrage(
    val frage: String,
    val antworten: List<String>,
    val richtigeAntwortIndex: Int,
    val erklaerung: String
)

object AppData {

    val uebersetzungen = listOf(
        Uebersetzung(
            wasSieSagt = "Es ist alles okay",
            wasSieMeint = "Es ist definitiv NICHT okay",
            emoji = "😤",
            tipp = "Nachfragen! „Bist du sicher, dass alles gut ist?" hilft mehr als Schweigen."
        ),
        Uebersetzung(
            wasSieSagt = "Mach was du willst",
            wasSieMeint = "Tu das bloß nicht!",
            emoji = "⚠️",
            tipp = "Niemals wörtlich nehmen. Am besten Optionen anbieten und gemeinsam entscheiden."
        ),
        Uebersetzung(
            wasSieSagt = "Ich bin gleich fertig",
            wasSieMeint = "Noch mindestens 20 Minuten",
            emoji = "⏰",
            tipp = "Einfach 20 Minuten extra einplanen und in Ruhe warten."
        ),
        Uebersetzung(
            wasSieSagt = "Wir müssen reden",
            wasSieMeint = "Du bist in großen Schwierigkeiten",
            emoji = "😰",
            tipp = "Sofort volles Gehör schenken, Handy weglegen, nicht defensiv werden."
        ),
        Uebersetzung(
            wasSieSagt = "Ich brauche nichts zum Geburtstag",
            wasSieMeint = "Überrasch mich mit etwas Schönem",
            emoji = "🎁",
            tipp = "Immer etwas kaufen – kein Risiko eingehen! Lieber zu viel als zu wenig."
        ),
        Uebersetzung(
            wasSieSagt = "Das macht nichts",
            wasSieMeint = "Das macht sehr wohl etwas",
            emoji = "🙄",
            tipp = "Aufrichtig entschuldigen, auch wenn du nicht genau weißt, wofür."
        ),
        Uebersetzung(
            wasSieSagt = "Ich bin nicht böse",
            wasSieMeint = "Ich bin sehr böse",
            emoji = "😠",
            tipp = "Ruhe bewahren, nicht streiten, Zeit und Raum geben."
        ),
        Uebersetzung(
            wasSieSagt = "Du entscheidest",
            wasSieMeint = "Sag auf keinen Fall das Falsche",
            emoji = "🎯",
            tipp = "2–3 konkrete Optionen vorschlagen und nach ihrer Meinung fragen."
        ),
        Uebersetzung(
            wasSieSagt = "Kein Stress, kauf was du willst",
            wasSieMeint = "Kauf bitte das Richtige",
            emoji = "🛍️",
            tipp = "Vor dem Kauf nochmals fragen, welches sie gemeint hat."
        ),
        Uebersetzung(
            wasSieSagt = "Mir ist kalt",
            wasSieMeint = "Ich möchte deine Jacke",
            emoji = "🧥",
            tipp = "Die Jacke anbieten, bevor sie fragen muss."
        ),
        Uebersetzung(
            wasSieSagt = "Wir schauen was du willst",
            wasSieMeint = "Wir schauen was ich will",
            emoji = "📺",
            tipp = "Fragen was sie gern sehen möchte – und das dann wirklich anschalten."
        ),
        Uebersetzung(
            wasSieSagt = "Ich bin nicht hungrig",
            wasSieMeint = "Ich esse von deinem Teller",
            emoji = "🍽️",
            tipp = "Immer eine Portion extra bestellen oder teilen."
        )
    )

    val stimmungen = listOf(
        Stimmung(
            name = "Glücklich",
            emoji = "😊",
            beschreibung = "Sie ist in bester Laune und strahlt Energie aus.",
            signale = listOf(
                "Lacht viel und häufig",
                "Ist besonders gesprächig",
                "Macht spontan Pläne",
                "Schickt süße Nachrichten"
            ),
            wasZuTun = "Genieß den Moment! Jetzt ist die perfekte Zeit für besondere Vorschläge oder gemeinsame Aktivitäten.",
            farbe = Color(0xFF4CAF50)
        ),
        Stimmung(
            name = "Verliebt",
            emoji = "🥰",
            beschreibung = "Sie ist in romantischer Stimmung und will Nähe.",
            signale = listOf(
                "Sucht Körperkontakt",
                "Schaut dich häufig an",
                "Schreibt öfter als sonst",
                "Ist besonders zuvorkommend"
            ),
            wasZuTun = "Romantisch sein! Komplimente machen, Aufmerksamkeit schenken, vielleicht eine Überraschung planen.",
            farbe = Color(0xFFE91E8C)
        ),
        Stimmung(
            name = "Nachdenklich",
            emoji = "🤔",
            beschreibung = "Sie verarbeitet gerade etwas innerlich.",
            signale = listOf(
                "Ist ruhiger als sonst",
                "Schaut manchmal ins Leere",
                "Antwortet einsilbig",
                "Seufzt hin und wieder"
            ),
            wasZuTun = "Raum lassen und nicht drängen. Sanft fragen ob alles okay ist – und dann wirklich zuhören.",
            farbe = Color(0xFF9C27B0)
        ),
        Stimmung(
            name = "Gestresst",
            emoji = "😰",
            beschreibung = "Sie steht unter Druck und braucht Entlastung.",
            signale = listOf(
                "Multitasking im Overdrive",
                "Spricht schnell und gehetzt",
                "Vergisst Kleinigkeiten",
                "Wirkt ungeduldig"
            ),
            wasZuTun = "Keine zusätzlichen Aufgaben! Fragen: „Wie kann ich helfen?" – und dann wirklich helfen, ohne Kommentar.",
            farbe = Color(0xFFFF9800)
        ),
        Stimmung(
            name = "Frustriert",
            emoji = "😤",
            beschreibung = "Irgendetwas nervt sie gerade gewaltig.",
            signale = listOf(
                "Kurze, knappe Antworten",
                "Rollt die Augen",
                "Seufzt laut",
                "Ist schnell genervt"
            ),
            wasZuTun = "NIEMALS fragen: „Liegt das an deiner Periode?" Stattdessen: Zuhören, Verständnis zeigen, keine Ratschläge.",
            farbe = Color(0xFFFF5722)
        ),
        Stimmung(
            name = "Traurig",
            emoji = "😢",
            beschreibung = "Sie braucht emotionale Unterstützung und Nähe.",
            signale = listOf(
                "Zieht sich zurück",
                "Ist ungewöhnlich still",
                "Hat feuchte Augen",
                "Möchte umarmt werden"
            ),
            wasZuTun = "Einfach da sein. Umarmen. Zuhören ohne zu bewerten. Keine Lösungen – nur echtes Mitgefühl.",
            farbe = Color(0xFF2196F3)
        ),
        Stimmung(
            name = "Wütend",
            emoji = "😠",
            beschreibung = "Vorsicht – kritische Situation! Ruhe bewahren.",
            signale = listOf(
                "Erhobene Stimme",
                "Verschränkte Arme",
                "Schroffe Worte",
                "Schlägt vielleicht Türen"
            ),
            wasZuTun = "NIEMALS sagen: „Beruhig dich mal!" Das macht es schlimmer. Zuhören, nicht unterbrechen, ernst nehmen.",
            farbe = Color(0xFFF44336)
        ),
        Stimmung(
            name = "Müde",
            emoji = "😴",
            beschreibung = "Sie braucht Ruhe, Stille und Erholung.",
            signale = listOf(
                "Gähnt häufig",
                "Langsame Reaktionen",
                "Will früh ins Bett",
                "Redet weniger"
            ),
            wasZuTun = "Lass sie schlafen! Mach Tee, übernimm Aufgaben still und leise – und stell heute keine wichtigen Fragen.",
            farbe = Color(0xFF607D8B)
        )
    )

    val tipps = listOf(
        Tipp(
            titel = "Zuhören ohne zu lösen",
            inhalt = "Wenn sie über Probleme spricht, will sie oft kein Lösungsangebot – sie will gehört werden. Sag: „Das klingt wirklich schwierig" statt sofort Ratschläge zu geben. Erst dann fragen: „Möchtest du, dass ich helfe, oder brauchst du jemanden zum Reden?"",
            icon = "👂",
            kategorie = "Kommunikation"
        ),
        Tipp(
            titel = "Daten und Details merken",
            inhalt = "Merke dir wichtige Daten: Geburtstag, Jahrestag, das Datum des ersten Dates. Erinnere dich an kleine Details aus Gesprächen – das zeigt, dass dir wichtig ist, was sie sagt.",
            icon = "📅",
            kategorie = "Alltag"
        ),
        Tipp(
            titel = "Echte Komplimente machen",
            inhalt = "Nicht nur das Aussehen loben – bemerke auch ihre Intelligenz, Kreativität oder Entscheidungen. „Du hast das wirklich clever gelöst" trifft oft tiefer als „Du siehst heute gut aus".",
            icon = "💬",
            kategorie = "Komplimente"
        ),
        Tipp(
            titel = "Streit: Das richtige Timing",
            inhalt = "Nie streiten, wenn sie hungrig, müde oder frisch nach der Arbeit ist. Warte einen ruhigen Moment ab. Ein Gespräch beim Spazierengehen (ohne direkten Blickkontakt) ist oft leichter als am Tisch gegenüber.",
            icon = "⏱️",
            kategorie = "Streit vermeiden"
        ),
        Tipp(
            titel = "Kleine Gesten, große Wirkung",
            inhalt = "Kaffee machen ohne Frage, spontan Blumen kaufen, eine Nachricht schicken: „Ich denke an dich." Kleine unerwartete Gesten haben oft mehr Wirkung als große geplante Aktionen.",
            icon = "🌸",
            kategorie = "Romantik"
        ),
        Tipp(
            titel = "Gefühle niemals relativieren",
            inhalt = "Wenn sie sich über etwas beschwert, sag nie „Das ist doch nicht so schlimm" oder „Anderen geht es schlechter." Das fühlt sich wie Ablehnung an. Stattdessen: ihre Gefühle validieren.",
            icon = "🚫",
            kategorie = "Kommunikation"
        ),
        Tipp(
            titel = "Echtes Interesse zeigen",
            inhalt = "Frag nach ihrem Tag – und hör wirklich zu. Leg das Handy weg. Stell Rückfragen. Zeig durch Mimik, dass du aufmerksam bist – auch bei Themen, die dich kaum interessieren.",
            icon = "❤️",
            kategorie = "Alltag"
        ),
        Tipp(
            titel = "Richtig entschuldigen",
            inhalt = "Eine echte Entschuldigung enthält: was du falsch gemacht hast + dass es dir leid tut + wie du es besser machen wirst. „Tut mir leid, aber…" ist keine Entschuldigung – das „aber" macht alles kaputt.",
            icon = "🙏",
            kategorie = "Streit vermeiden"
        ),
        Tipp(
            titel = "Überraschungen planen",
            inhalt = "Überraschungen müssen nicht teuer sein: ein Lieblingsessen kochen, ein unerwarteter Ausflug, eine Playlist mit „unseren Songs". Die Mühe dahinter ist das, was zählt.",
            icon = "🎉",
            kategorie = "Romantik"
        ),
        Tipp(
            titel = "Körperliche Nähe",
            inhalt = "Manchmal ist eine Umarmung wertvoller als tausend Worte. Eine Hand auf der Schulter, zusammen auf der Couch sitzen – physische Nähe signalisiert Sicherheit und Verbundenheit.",
            icon = "🤗",
            kategorie = "Romantik"
        ),
        Tipp(
            titel = "Gemeinsam Entscheidungen treffen",
            inhalt = "Bei wichtigen Entscheidungen (Urlaub, Restaurant, Wochenendpläne) nicht einfach alleine entscheiden. Optionen vorstellen und gemeinsam wählen – das stärkt das Gefühl als Team.",
            icon = "🤝",
            kategorie = "Alltag"
        ),
        Tipp(
            titel = "Lob im richtigen Moment",
            inhalt = "Lobe sie vor anderen – aber diskret. Wenn du sie im Beisein von Freunden oder Familie für etwas lobst, das ihr wichtig ist, hat das eine besondere Wirkung.",
            icon = "⭐",
            kategorie = "Komplimente"
        )
    )

    val quizFragen = listOf(
        QuizFrage(
            frage = "Sie sagt „Ich bin nicht böse". Was bedeutet das wirklich?",
            antworten = listOf(
                "Sie ist wirklich nicht böse",
                "Sie ist sehr wohl böse",
                "Sie ist unentschlossen",
                "Sie redet von jemand anderem"
            ),
            richtigeAntwortIndex = 1,
            erklaerung = "Der Klassiker! „Ich bin nicht böse" bedeutet fast immer das genaue Gegenteil. Am besten: Nachfragen, zuhören, Verständnis zeigen."
        ),
        QuizFrage(
            frage = "Sie sagt „Du entscheidest" bei der Restaurantwahl. Was tust du?",
            antworten = listOf(
                "Einfach irgendein Restaurant aussuchen",
                "2–3 Optionen nennen und ihre Meinung einholen",
                "Sagen dass du auch keine Ahnung hast",
                "Fast Food vorschlagen"
            ),
            richtigeAntwortIndex = 1,
            erklaerung = "„Du entscheidest" heißt nicht wirklich „entscheid allein." Schlag Optionen vor und frag, was ihr besser gefällt. So teilt ihr die Entscheidung."
        ),
        QuizFrage(
            frage = "Sie erzählt dir ein Problem bei der Arbeit. Was ist deine erste Reaktion?",
            antworten = listOf(
                "Sofort Lösungen vorschlagen",
                "Zuhören, Verständnis zeigen und nachfragen",
                "Sagen dass andere es schlimmer haben",
                "Das Handy weglegen und nicken ohne zuzuhören"
            ),
            richtigeAntwortIndex = 1,
            erklaerung = "Frauen wollen bei Problemen oft zuerst gehört werden, nicht gleich Lösungen hören. Erst zuhören und validieren – dann fragen, ob sie Hilfe möchte!"
        ),
        QuizFrage(
            frage = "Wie lange dauert „Ich bin gleich fertig" wirklich?",
            antworten = listOf(
                "Genau 2–3 Minuten",
                "Genau 5 Minuten",
                "Mindestens 15–20 Minuten",
                "Je nach Tagesform 1–2 Stunden"
            ),
            richtigeAntwortIndex = 2,
            erklaerung = "Die universelle Wahrheit: „gleich fertig" = mindestens 15–20 Minuten. Einfach entsprechend einplanen – kein Stress!"
        ),
        QuizFrage(
            frage = "Sie ist offensichtlich verärgert. Was sagst du auf keinen Fall?",
            antworten = listOf(
                "„Was ist los? Erzähl mir davon."",
                "„Beruhig dich mal!"",
                "„Ich höre dir zu."",
                "„Wie kann ich helfen?""
            ),
            richtigeAntwortIndex = 1,
            erklaerung = "„Beruhig dich!" ist der schlimmste Satz. Er signalisiert, dass ihre Gefühle nicht gerechtfertigt sind – und macht es nur schlimmer!"
        ),
        QuizFrage(
            frage = "Welche Art von Kompliment trifft am tiefsten?",
            antworten = listOf(
                "„Du siehst heute heiß aus."",
                "„Dein Outfit ist toll."",
                "„Ich bewundere, wie du dieses Problem gelöst hast."",
                "„Du hast schöne Haare.""
            ),
            richtigeAntwortIndex = 2,
            erklaerung = "Komplimente über Charakter, Intelligenz und Fähigkeiten sind wertvoller als rein äußerliche. Sie zeigen, dass du die Person schätzt – nicht nur das Aussehen."
        ),
        QuizFrage(
            frage = "Sie sagt „Ich brauche nichts zum Geburtstag." Was machst du?",
            antworten = listOf(
                "Nichts kaufen – sie hat es ja gesagt",
                "Ein durchdachtes Geschenk kaufen",
                "Geld ins Kuvert stecken",
                "Fragen was sie will"
            ),
            richtigeAntwortIndex = 1,
            erklaerung = "Immer ein Geschenk kaufen! „Ich brauche nichts" bedeutet: Überrasch mich mit etwas Schönem und Durchdachtem."
        ),
        QuizFrage(
            frage = "Was ist der schlechteste Zeitpunkt für ein ernstes Gespräch?",
            antworten = listOf(
                "Nach dem gemeinsamen Abendessen",
                "Direkt wenn sie von der Arbeit nach Hause kommt",
                "Sonntagnachmittag beim Spaziergang",
                "Am ruhigen Samstagmorgen"
            ),
            richtigeAntwortIndex = 1,
            erklaerung = "Direkt nach einem stressigen Arbeitstag ist der schlechteste Moment. Warte, bis sie sich entspannt, gegessen und erholt hat."
        ),
        QuizFrage(
            frage = "Eine echte Entschuldigung enthält...",
            antworten = listOf(
                "Nur das Wort „Sorry"",
                "„Tut mir leid, aber du hast auch…"",
                "Anerkennung des Fehlers + Bedauern + konkretes Besserungsversprechen",
                "Eine ausführliche Erklärung warum du es getan hast"
            ),
            richtigeAntwortIndex = 2,
            erklaerung = "Eine echte Entschuldigung hat drei Teile: den Fehler anerkennen, aufrichtig bedauern und konkret versprechen, was du anders machst. Das „aber" macht alles kaputt!"
        ),
        QuizFrage(
            frage = "„Wir müssen reden." – Was ist deine erste Reaktion?",
            antworten = listOf(
                "Entspannt bleiben, wird schon nichts sein",
                "Vollständige Aufmerksamkeit geben und zuhörbereit sein",
                "Schnell das Thema wechseln",
                "Auf später vertrösten"
            ),
            richtigeAntwortIndex = 1,
            erklaerung = "„Wir müssen reden" ist ein wichtiges Signal. Jetzt Handy weglegen, volle Aufmerksamkeit schenken und offen in das Gespräch gehen."
        )
    )
}
