package com.wolfsrudelgaming.frauenverstehen.ui.screens

import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
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
import com.wolfsrudelgaming.frauenverstehen.data.Tipp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TippsScreen() {
    val kategorien = listOf("Alle") + AppData.tipps.map { it.kategorie }.distinct()
    var gewaehlteKategorie by remember { mutableStateOf("Alle") }

    val gefilterteTipps = if (gewaehlteKategorie == "Alle") {
        AppData.tipps
    } else {
        AppData.tipps.filter { it.kategorie == gewaehlteKategorie }
    }

    Column(modifier = Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text("💡 Tipps & Tricks", fontWeight = FontWeight.Bold) },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = Color(0xFFFF9800),
                titleContentColor = Color.White
            )
        )
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background)
        ) {
            item {
                LazyRow(
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)
                ) {
                    itemsIndexed(kategorien) { _, kategorie ->
                        FilterChip(
                            selected = gewaehlteKategorie == kategorie,
                            onClick = { gewaehlteKategorie = kategorie },
                            label = { Text(kategorie, fontSize = 13.sp) },
                            modifier = Modifier.padding(end = 8.dp),
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = Color(0xFFFF9800),
                                selectedLabelColor = Color.White
                            )
                        )
                    }
                }
            }
            itemsIndexed(gefilterteTipps) { _, tipp ->
                TippKarte(tipp)
            }
            item { Spacer(Modifier.height(8.dp)) }
        }
    }
}

@Composable
private fun TippKarte(tipp: Tipp) {
    val kategoriefarbe = when (tipp.kategorie) {
        "Kommunikation" -> Color(0xFF1976D2)
        "Alltag" -> Color(0xFF388E3C)
        "Romantik" -> Color(0xFFE91E8C)
        "Streit vermeiden" -> Color(0xFFD32F2F)
        "Komplimente" -> Color(0xFF7B1FA2)
        else -> Color(0xFF757575)
    }

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 6.dp),
        shape = RoundedCornerShape(16.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.Top
        ) {
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(kategoriefarbe.copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center
            ) {
                Text(tipp.icon, fontSize = 24.sp)
            }
            Spacer(Modifier.width(14.dp))
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = tipp.titel,
                        fontWeight = FontWeight.Bold,
                        fontSize = 15.sp,
                        modifier = Modifier.weight(1f)
                    )
                }
                Spacer(Modifier.height(2.dp))
                Box(
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(kategoriefarbe.copy(alpha = 0.15f))
                        .padding(horizontal = 8.dp, vertical = 2.dp)
                ) {
                    Text(
                        text = tipp.kategorie,
                        fontSize = 10.sp,
                        color = kategoriefarbe,
                        fontWeight = FontWeight.Medium
                    )
                }
                Spacer(Modifier.height(6.dp))
                Text(
                    text = tipp.inhalt,
                    fontSize = 13.sp,
                    lineHeight = 19.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}
