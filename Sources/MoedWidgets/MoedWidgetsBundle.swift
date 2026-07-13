//
//  MoedWidgetsBundle.swift
//  MoedWidgets — extension WidgetKit
//
//  Point d'entrée de l'extension : déclare les trois widgets home-screen /
//  Lock Screen de Moed (DESIGN §11). Tous RECALCULENT localement via
//  `WidgetEngine` — 100 % offline, aucun réseau, aucun conteneur partagé, parité
//  de calcul avec l'app (CONTRACTS §4.4).
//
//  • CandleWidget  — allumage + compte à rebours + parasha (small / medium / Lock).
//  • ZmanimWidget  — zmanim clés du jour, prochain surligné (medium).
//  • OmerWidget    — jour du Omer (small / Lock circulaire + rectangulaire).
//

import WidgetKit
import SwiftUI

@main
struct MoedWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CandleWidget()
        ZmanimWidget()
        OmerWidget()
    }
}
