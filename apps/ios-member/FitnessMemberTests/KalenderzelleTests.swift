import SwiftUI
import Testing
@testable import FitnessMember

/// Die Farbregel der Tageszelle -- zwei Kanaele, und nur zwei: die
/// FUELLUNG sagt, was der Tag ist (nichts, trainiert, gewaehlt), der
/// RING sagt heute. Die Tests halten fest, dass sich die beiden nie ins
/// Gehege kommen, denn genau daran gingen die zwei frueheren Zellen
/// auseinander: der Kursplan fuellte die Auswahl mit `accent` und
/// markierte heute gar nicht, Home fuellte sie mit `line`.
struct KalenderzelleTests {

    // MARK: - Fuellung: was der Tag ist

    /// Gewaehlt schlaegt trainiert, sonst haette ein trainierter Tag
    /// zwei verschiedene Auswahl-Fuellungen.
    @Test func gewaehltIstWeissGefuellt() {
        #expect(
            Kalenderfarben.fuellung(istGewaehlt: true, trainiert: false)
                == DesignSystem.Color.text)
        #expect(
            Kalenderfarben.fuellung(istGewaehlt: true, trainiert: true)
                == DesignSystem.Color.text)
    }

    @Test func trainiertUndNichtGewaehltTraegtDieErhoheneFlaeche() {
        #expect(
            Kalenderfarben.fuellung(istGewaehlt: false, trainiert: true)
                == DesignSystem.Color.surfaceRaised)
    }

    @Test func einLeererTagHatKeineFuellung() {
        #expect(Kalenderfarben.fuellung(istGewaehlt: false, trainiert: false) == Color.clear)
    }

    // MARK: - Vordergrund: was auf der Fuellung lesbar bleibt

    /// Auf der weissen Fuellung steht der Hintergrundton -- weiss auf
    /// weiss waere unsichtbar, und zwar in beiden Kalendern.
    @Test func aufDerWeissenFuellungStehtDerHintergrundton() {
        #expect(
            Kalenderfarben.vordergrund(istGewaehlt: true, trainiert: false, istHeute: false)
                == DesignSystem.Color.bg)
        #expect(
            Kalenderfarben.vordergrund(istGewaehlt: true, trainiert: true, istHeute: false)
                == DesignSystem.Color.bg)
        #expect(
            Kalenderfarben.vordergrund(istGewaehlt: true, trainiert: false, istHeute: true)
                == DesignSystem.Color.bg)
    }

    @Test func einTrainierterTagStehtInVollerTextfarbe() {
        #expect(
            Kalenderfarben.vordergrund(istGewaehlt: false, trainiert: true, istHeute: false)
                == DesignSystem.Color.text)
        #expect(
            Kalenderfarben.vordergrund(istGewaehlt: false, trainiert: true, istHeute: true)
                == DesignSystem.Color.text)
    }

    /// Heute hebt einen leeren Tag eine Stufe an -- der Ring allein
    /// liesse die Zahl darin so blass wie jede andere.
    @Test func einLeererHeutigerTagIstEineStufeHeller() {
        #expect(
            Kalenderfarben.vordergrund(istGewaehlt: false, trainiert: false, istHeute: true)
                == DesignSystem.Color.textMuted)
    }

    @Test func einLeererTagBleibtDieBlassesteStufe() {
        #expect(
            Kalenderfarben.vordergrund(istGewaehlt: false, trainiert: false, istHeute: false)
                == DesignSystem.Color.textFaint)
    }

    // MARK: - Ring: heute, und sonst nichts

    @Test func nurHeuteTraegtEinenRing() {
        #expect(Kalenderfarben.ring(istHeute: true) == DesignSystem.Color.accent)
        #expect(Kalenderfarben.ring(istHeute: false) == nil)
    }

    /// Der Fall, an dem sich die Trennung der beiden Kanaele entscheidet:
    /// ein Tag kann zugleich heute UND gewaehlt sein, und beide Aussagen
    /// muessen nebeneinander lesbar bleiben.
    @Test func gewaehltUndHeuteZeigtFuellungUndRing() {
        #expect(
            Kalenderfarben.fuellung(istGewaehlt: true, trainiert: false)
                == DesignSystem.Color.text)
        #expect(Kalenderfarben.ring(istHeute: true) == DesignSystem.Color.accent)
    }
}
