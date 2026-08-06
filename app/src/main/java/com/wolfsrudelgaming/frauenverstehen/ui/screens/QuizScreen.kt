package com.wolfsrudelgaming.frauenverstehen.ui.screens

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.wolfsrudelgaming.frauenverstehen.data.AppData

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuizScreen() {
    var aktuelleFrageIndex by remember { mutableIntStateOf(0) }
    var gewaehltAntwortIndex by remember { mutableStateOf<Int?>(null) }
    var antwortBestaetigt by remember { mutableStateOf(false) }
    var punkte by remember { mutableIntStateOf(0) }
    var quizBeendet by remember { mutableStateOf(false) }

    val fragen = AppData.quizFragen
    val aktuellerFortschritt = aktuelleFrageIndex.toFloat() / fragen.size

    Column(modifier = Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text("🧠 Quiz", fontWeight = FontWeight.Bold) },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = Color(0xFF1976D2),
                titleContentColor = Color.White
            )
        )

        if (quizBeendet) {
            ErgebnisBildschirm(
                punkte = punkte,
                gesamt = fragen.size,
                onNeustart = {
                    aktuelleFrageIndex = 0
                    gewaehltAntwortIndex = null
                    antwortBestaetigt = false
                    punkte = 0
                    quizBeendet = false
                }
            )
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.background)
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = "Frage ${aktuelleFrageIndex + 1} von ${fragen.size}",
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        text = "⭐ $punkte Punkte",
                        fontSize = 13.sp,
                        color = Color(0xFF1976D2),
                        fontWeight = FontWeight.Medium
                    )
                }
                Spacer(Modifier.height(8.dp))
                LinearProgressIndicator(
                    progress = { aktuellerFortschritt },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(6.dp)
                        .clip(CircleShape),
                    color = Color(0xFF1976D2),
                    trackColor = Color(0xFFBBDEFB)
                )
                Spacer(Modifier.height(20.dp))

                AnimatedContent(
                    targetState = aktuelleFrageIndex,
                    transitionSpec = {
                        (slideInHorizontally { it } + fadeIn()) togetherWith
                                (slideOutHorizontally { -it } + fadeOut())
                    },
                    label = "quiz-frage"
                ) { frageIndex ->
                    val frage = fragen[frageIndex]
                    Column {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(20.dp))
                                .background(Color(0xFF1976D2))
                                .padding(20.dp)
                        ) {
                            Text(
                                text = frage.frage,
                                fontSize = 17.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color.White,
                                lineHeight = 24.sp
                            )
                        }

                        Spacer(Modifier.height(16.dp))

                        frage.antworten.forEachIndexed { index, antwort ->
                            val istGewählt = gewaehltAntwortIndex == index
                            val istRichtig = index == frage.richtigeAntwortIndex

                            val hintergrund = when {
                                !antwortBestaetigt && istGewählt -> Color(0xFFE3F2FD)
                                antwortBestaetigt && istRichtig -> Color(0xFFE8F5E9)
                                antwortBestaetigt && istGewählt && !istRichtig -> Color(0xFFFFEBEE)
                                else -> MaterialTheme.colorScheme.surface
                            }
                            val rahmen = when {
                                !antwortBestaetigt && istGewählt -> Color(0xFF1976D2)
                                antwortBestaetigt && istRichtig -> Color(0xFF388E3C)
                                antwortBestaetigt && istGewählt && !istRichtig -> Color(0xFFD32F2F)
                                else -> Color(0xFFE0E0E0)
                            }
                            val prefix = when {
                                antwortBestaetigt && istRichtig -> "✅ "
                                antwortBestaetigt && istGewählt && !istRichtig -> "❌ "
                                else -> "${('A' + index)}. "
                            }

                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 5.dp)
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(hintergrund)
                                    .border(
                                        width = 2.dp,
                                        color = rahmen,
                                        shape = RoundedCornerShape(12.dp)
                                    )
                                    .clickable(enabled = !antwortBestaetigt) {
                                        gewaehltAntwortIndex = index
                                    }
                                    .padding(14.dp)
                            ) {
                                Text(
                                    text = "$prefix$antwort",
                                    fontSize = 14.sp,
                                    lineHeight = 20.sp,
                                    fontWeight = if (antwortBestaetigt && istRichtig) FontWeight.Bold else FontWeight.Normal
                                )
                            }
                        }

                        if (antwortBestaetigt) {
                            Spacer(Modifier.height(14.dp))
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(Color(0xFFFFF9C4))
                                    .padding(14.dp)
                            ) {
                                Text(
                                    text = "💡 ${frage.erklaerung}",
                                    fontSize = 13.sp,
                                    lineHeight = 19.sp,
                                    color = Color(0xFF5D4037)
                                )
                            }
                        }
                    }
                }

                Spacer(Modifier.height(20.dp))

                if (!antwortBestaetigt) {
                    Button(
                        onClick = {
                            if (gewaehltAntwortIndex != null) {
                                antwortBestaetigt = true
                                val aktuelleFrage = fragen[aktuelleFrageIndex]
                                if (gewaehltAntwortIndex == aktuelleFrage.richtigeAntwortIndex) {
                                    punkte++
                                }
                            }
                        },
                        enabled = gewaehltAntwortIndex != null,
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1976D2))
                    ) {
                        Text("Antwort bestätigen", fontSize = 15.sp, modifier = Modifier.padding(vertical = 4.dp))
                    }
                } else {
                    Button(
                        onClick = {
                            if (aktuelleFrageIndex < fragen.size - 1) {
                                aktuelleFrageIndex++
                                gewaehltAntwortIndex = null
                                antwortBestaetigt = false
                            } else {
                                quizBeendet = true
                            }
                        },
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF388E3C))
                    ) {
                        val label = if (aktuelleFrageIndex < fragen.size - 1) "Nächste Frage →" else "Ergebnis anzeigen 🏆"
                        Text(label, fontSize = 15.sp, modifier = Modifier.padding(vertical = 4.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun ErgebnisBildschirm(punkte: Int, gesamt: Int, onNeustart: () -> Unit) {
    val prozent = punkte.toFloat() / gesamt
    val (emoji, titel, text) = when {
        prozent >= 0.9f -> Triple("🏆", "Meisterklasse!", "Du verstehst Frauen wie kein anderer. Chapeau!")
        prozent >= 0.7f -> Triple("🌟", "Sehr gut!", "Du bist auf einem guten Weg. Noch ein bisschen Übung und du bist unschlagbar.")
        prozent >= 0.5f -> Triple("👍", "Solide!", "Nicht schlecht! Übe weiter und du wirst noch besser.")
        prozent >= 0.3f -> Triple("📚", "Ausbaufähig", "Lies nochmal durch die Tipps – da steckt viel Weisheit drin!")
        else -> Triple("💪", "Weiter üben!", "Keine Sorge – aus Fehlern lernt man am meisten. Viel Erfolg!")
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(Modifier.height(32.dp))
        Text(emoji, fontSize = 80.sp, textAlign = TextAlign.Center)
        Spacer(Modifier.height(16.dp))
        Text(
            text = titel,
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(8.dp))
        Text(
            text = text,
            fontSize = 15.sp,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            lineHeight = 22.sp
        )
        Spacer(Modifier.height(32.dp))
        Box(
            modifier = Modifier
                .size(140.dp)
                .clip(CircleShape)
                .background(Color(0xFF1976D2).copy(alpha = 0.1f))
                .border(4.dp, Color(0xFF1976D2), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = "$punkte/$gesamt",
                    fontSize = 32.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFF1976D2)
                )
                Text(
                    text = "Punkte",
                    fontSize = 14.sp,
                    color = Color(0xFF1976D2)
                )
            }
        }
        Spacer(Modifier.height(40.dp))
        Button(
            onClick = onNeustart,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1976D2))
        ) {
            Text("Quiz wiederholen 🔄", fontSize = 15.sp, modifier = Modifier.padding(vertical = 4.dp))
        }
        Spacer(Modifier.height(12.dp))
        OutlinedButton(
            onClick = onNeustart,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        ) {
            Text("Zurück zum Start", fontSize = 15.sp, modifier = Modifier.padding(vertical = 4.dp))
        }
    }
}
