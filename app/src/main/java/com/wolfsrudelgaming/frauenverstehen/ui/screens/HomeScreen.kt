package com.wolfsrudelgaming.frauenverstehen.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private data class FeatureCard(
    val titel: String,
    val beschreibung: String,
    val emoji: String,
    val gradient: List<Color>
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen() {
    val features = listOf(
        FeatureCard(
            "Übersetzer",
            "Was sie sagt vs. was sie meint",
            "🔤",
            listOf(Color(0xFFE91E8C), Color(0xFFC2185B))
        ),
        FeatureCard(
            "Stimmungskompass",
            "Ihre aktuelle Stimmung deuten",
            "🧭",
            listOf(Color(0xFF9C27B0), Color(0xFF673AB7))
        ),
        FeatureCard(
            "Tipps & Tricks",
            "Kommunikation verbessern",
            "💡",
            listOf(Color(0xFFFF9800), Color(0xFFE64A19))
        ),
        FeatureCard(
            "Quiz",
            "Teste dein Wissen",
            "🧠",
            listOf(Color(0xFF1976D2), Color(0xFF0D47A1))
        )
    )

    LazyVerticalGrid(
        columns = GridCells.Fixed(2),
        contentPadding = PaddingValues(bottom = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        item(span = { GridItemSpan(2) }) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        Brush.verticalGradient(
                            listOf(Color(0xFFE91E8C), Color(0xFFAD1457))
                        )
                    )
                    .padding(horizontal = 24.dp, vertical = 32.dp),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("👩", fontSize = 56.sp)
                    Spacer(Modifier.height(12.dp))
                    Text(
                        text = "Frauen verstehen",
                        fontSize = 26.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White,
                        textAlign = TextAlign.Center
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        text = "Dein persönlicher Beziehungsratgeber",
                        fontSize = 13.sp,
                        color = Color.White.copy(alpha = 0.85f),
                        textAlign = TextAlign.Center
                    )
                }
            }
        }

        item(span = { GridItemSpan(2) }) {
            Text(
                text = "Was möchtest du lernen?",
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.padding(start = 16.dp, top = 8.dp, bottom = 4.dp)
            )
        }

        items(features.size) { index ->
            val feature = features[index]
            Card(
                modifier = Modifier
                    .padding(
                        start = if (index % 2 == 0) 16.dp else 0.dp,
                        end = if (index % 2 == 1) 16.dp else 0.dp
                    )
                    .aspectRatio(1f),
                shape = RoundedCornerShape(20.dp),
                elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(Brush.verticalGradient(feature.gradient)),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center,
                        modifier = Modifier.padding(16.dp)
                    ) {
                        Text(feature.emoji, fontSize = 42.sp)
                        Spacer(Modifier.height(10.dp))
                        Text(
                            text = feature.titel,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White,
                            textAlign = TextAlign.Center
                        )
                        Spacer(Modifier.height(4.dp))
                        Text(
                            text = feature.beschreibung,
                            fontSize = 11.sp,
                            color = Color.White.copy(alpha = 0.85f),
                            textAlign = TextAlign.Center,
                            lineHeight = 14.sp
                        )
                    }
                }
            }
        }

        item(span = { GridItemSpan(2) }) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                colors = CardDefaults.cardColors(
                    containerColor = Color(0xFFFCE4EC)
                ),
                shape = RoundedCornerShape(16.dp)
            ) {
                Text(
                    text = "💡 Tipp des Tages\n\nKleine unerwartete Gesten haben oft mehr Wirkung als große geplante Aktionen. Ein spontaner Kaffee oder eine kurze „Ich denke an dich"-Nachricht kann den ganzen Tag erhellen.",
                    modifier = Modifier.padding(16.dp),
                    fontSize = 13.sp,
                    lineHeight = 20.sp,
                    color = Color(0xFF880E4F)
                )
            }
        }
    }
}
