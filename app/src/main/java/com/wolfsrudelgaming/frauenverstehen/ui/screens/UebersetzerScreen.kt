package com.wolfsrudelgaming.frauenverstehen.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.wolfsrudelgaming.frauenverstehen.data.AppData
import com.wolfsrudelgaming.frauenverstehen.data.Uebersetzung

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UebersetzerScreen() {
    Column(modifier = Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text("🔤 Übersetzer", fontWeight = FontWeight.Bold) },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = Color(0xFFE91E8C),
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
                    text = "Tippe auf einen Satz, um die echte Bedeutung zu enthüllen",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)
                )
            }
            itemsIndexed(AppData.uebersetzungen) { _, eintrag ->
                UebersetzungKarte(eintrag)
            }
            item { Spacer(Modifier.height(8.dp)) }
        }
    }
}

@Composable
private fun UebersetzungKarte(eintrag: Uebersetzung) {
    var aufgeklappt by remember { mutableStateOf(false) }

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
                        .size(44.dp)
                        .clip(CircleShape)
                        .background(Color(0xFFFCE4EC)),
                    contentAlignment = Alignment.Center
                ) {
                    Text(eintrag.emoji, fontSize = 22.sp)
                }
                Spacer(Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "Sie sagt:",
                        fontSize = 11.sp,
                        color = Color(0xFFE91E8C),
                        fontWeight = FontWeight.Medium
                    )
                    Text(
                        text = "„${eintrag.wasSieSagt}"",
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 15.sp,
                        fontStyle = FontStyle.Italic
                    )
                }
                Icon(
                    imageVector = if (aufgeklappt) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore,
                    contentDescription = null,
                    tint = Color(0xFFE91E8C)
                )
            }

            AnimatedVisibility(
                visible = aufgeklappt,
                enter = expandVertically(),
                exit = shrinkVertically()
            ) {
                Column {
                    Divider(color = Color(0xFFF8BBD0), thickness = 1.dp)
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(
                                Brush.verticalGradient(
                                    listOf(Color(0xFFFCE4EC), Color(0xFFFFF0F5))
                                )
                            )
                            .padding(16.dp)
                    ) {
                        Text(
                            text = "Sie meint:",
                            fontSize = 11.sp,
                            color = Color(0xFFC2185B),
                            fontWeight = FontWeight.Medium
                        )
                        Spacer(Modifier.height(2.dp))
                        Text(
                            text = eintrag.wasSieMeint,
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp,
                            color = Color(0xFF880E4F)
                        )
                        Spacer(Modifier.height(10.dp))
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(10.dp))
                                .background(Color(0xFFE8F5E9))
                                .padding(10.dp),
                            verticalAlignment = Alignment.Top
                        ) {
                            Text("💡 ", fontSize = 14.sp)
                            Text(
                                text = eintrag.tipp,
                                fontSize = 13.sp,
                                lineHeight = 18.sp,
                                color = Color(0xFF2E7D32)
                            )
                        }
                    }
                }
            }
        }
    }
}
