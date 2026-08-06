package com.wolfsrudelgaming.frauenverstehen.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Divider
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.wolfsrudelgaming.frauenverstehen.data.AppData
import com.wolfsrudelgaming.frauenverstehen.data.Stimmung

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StimmungskompassScreen() {
    Column(modifier = Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text("🧭 Stimmungskompass", fontWeight = FontWeight.Bold) },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = Color(0xFF9C27B0),
                titleContentColor = Color.White
            )
        )
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background)
        ) {
            item {
                Text(
                    text = "Welche Stimmung erkennst du gerade?",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)
                )
            }
            itemsIndexed(AppData.stimmungen) { _, stimmung ->
                StimmungsKarte(stimmung)
            }
            item { Spacer(Modifier.height(8.dp)) }
        }
    }
}

@Composable
private fun StimmungsKarte(stimmung: Stimmung) {
    var aufgeklappt by remember { mutableStateOf(false) }
    val accentColor = stimmung.farbe

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 6.dp)
            .clickable { aufgeklappt = !aufgeklappt },
        shape = RoundedCornerShape(16.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .clip(CircleShape)
                        .background(accentColor.copy(alpha = 0.15f)),
                    contentAlignment = Alignment.Center
                ) {
                    Text(stimmung.emoji, fontSize = 26.sp)
                }
                Spacer(Modifier.width(14.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = stimmung.name,
                        fontWeight = FontWeight.Bold,
                        fontSize = 17.sp
                    )
                    Text(
                        text = stimmung.beschreibung,
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        lineHeight = 16.sp
                    )
                }
                Box(
                    modifier = Modifier
                        .size(10.dp)
                        .clip(CircleShape)
                        .background(accentColor)
                )
                Spacer(Modifier.width(8.dp))
                Icon(
                    imageVector = if (aufgeklappt) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore,
                    contentDescription = null,
                    tint = accentColor
                )
            }

            AnimatedVisibility(
                visible = aufgeklappt,
                enter = expandVertically(),
                exit = shrinkVertically()
            ) {
                Column {
                    Divider(color = accentColor.copy(alpha = 0.2f), thickness = 1.dp)
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(accentColor.copy(alpha = 0.05f))
                            .padding(16.dp)
                    ) {
                        Text(
                            text = "Erkennungszeichen",
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 13.sp,
                            color = accentColor
                        )
                        Spacer(Modifier.height(6.dp))
                        stimmung.signale.forEach { signal ->
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.padding(vertical = 2.dp)
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(6.dp)
                                        .clip(CircleShape)
                                        .background(accentColor)
                                )
                                Spacer(Modifier.width(8.dp))
                                Text(
                                    text = signal,
                                    fontSize = 13.sp,
                                    lineHeight = 18.sp
                                )
                            }
                        }
                        Spacer(Modifier.height(14.dp))
                        Text(
                            text = "Was tun?",
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 13.sp,
                            color = accentColor
                        )
                        Spacer(Modifier.height(6.dp))
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(10.dp))
                                .background(accentColor.copy(alpha = 0.12f))
                                .padding(12.dp),
                            verticalAlignment = Alignment.Top,
                            horizontalArrangement = Arrangement.Start
                        ) {
                            Text("→ ", fontSize = 14.sp, color = accentColor, fontWeight = FontWeight.Bold)
                            Text(
                                text = stimmung.wasZuTun,
                                fontSize = 13.sp,
                                lineHeight = 19.sp
                            )
                        }
                    }
                }
            }
        }
    }
}
