# Offline-Stabilität der Member-App – Design

## Anlass

Beim Training im Studio (komplett im Keller) war das Netz zeitweise weg. Dabei ist zweierlei aufgefallen:

- **Suche:** Die App ist **teilweise eingefroren**, sobald man auf die Suche ging.
- **Einweisung:** Dasselbe passierte beim Öffnen einer Übung, deren Einweisung erst geladen werden musste.

**Ziel:** Kurze Funklöcher im Studio stören das Training nicht.
- Suchen, Übung öffnen, Einweisung lesen und Video sehen funktionieren ohne Netz und reagieren sofort.
- Kein geloggter Satz geht verloren.
- Niemand wird ohne Netz abgemeldet.

**Annahme:** Die App war vorher mindestens einmal online. Die allererste Nutzung ganz ohne Netz ist kein Ziel.

## Befund (Code-Stand 15.10.)

Pfade relativ zu `apps/ios-member/FitnessMember/`.

### Suche

- Sie filtert lokal den Bootstrap im Speicher und fragt den Server nicht.
- Das Filtern läuft synchron in `body` bei jedem Tastendruck (`GeraeteAuswahlView.swift:216`).
- `Zeitpunkt.swift:15-18` legt pro Aufruf zwei neue `ISO8601DateFormatter` an.

### Netz-Schicht

- `APIClient` nutzt `URLSession.shared` ohne Konfiguration. Damit gilt ein Timeout von 60 s.
- Es gibt keinen schnellen Abbruch, wenn `NetzwerkMonitor` offline meldet.
- `Medienablage` legt für jeden Download eine neue ephemere Session an.

### Gerätefoto

- `Geraetefoto` (`DesignSystem/Components/Vorschaubild.swift:177`) lädt Originale bis 10 MB per `UIImage(contentsOfFile:)`.
- Dekodiert wird beim Rendern auf dem Main-Thread.

### Einweisung

- Text, Video-URL und Foto-URL kommen nur aus dem Gerätekontext, der live geladen wird (`kontextLaden`).
- Offline fehlt der Text immer.
- Beim Video steht „Einweisungsvideo braucht Empfang“, auch wenn die Datei längst in der Medienablage liegt. Grund ist der Guard auf `videoURL` in `EinweisungSchritt.swift:125`.

### Bootstrap

- Er liegt nur im Speicher (`CatalogStore.swift:33`), obwohl die Fundament-Spec einen Bootstrap-Cache vorsieht.
- Ein Kaltstart ohne Netz endet auf „NICHT GELADEN“, und kein Training ist möglich.

### Auth

- `SupabaseAuthBackend.currentSession()` ruft `client.session` auf. Bei abgelaufenem Token macht das einen Refresh übers Netz.
- Scheitert dieser Refresh offline, ist das Ergebnis `nil`, und die App zeigt den **Login-Screen**, obwohl die Session in der Keychain liegt.

### Satzverlust

- Liefert der `tokenProvider` keinen Token, geht der Request **ohne** `Authorization` raus.
- Bei halbem Netz antwortet der Server dann mit 401.
- `.unauthorized` gilt in `APIError.istDauerhaft` als dauerhaft, also verschiebt `flushPending` den Satz endgültig nach `verworfeneWrites`.

### Was schon trägt

- Sätze loggen offline über die Warteschlange (`PendingWriteStore`, idempotenter PUT).
- Medienablage für Videos und Fotos.
- Caches für Verlauf und Kurse.
- `OfflineLeiste`.

## Entscheidungen (Brainstorming 15.10.)

1. **Ansatz A:** erst messen, dann gezielt härten. Kein vollständiger Offline-Modus.
2. **Alles in einer Spec**, auch die Fixes für Login-Verlust und Satzverlust.
3. **Videos werden vorgeladen, auch über Mobilfunk.** Das sind ~35 KB pro Video, ~6 MB für den ganzen Katalog.
4. **Kein Cache für den Gerätekontext.** Der Lastvorschlag fehlt offline weiterhin.

## Abgrenzung

- Die erste Nutzung ganz ohne Netz bleibt unbehandelt.
- Für den Gerätekontext (Lastvorschlag, signierte URLs) gibt es keinen Offline-Ersatz.
- Sätze, die früher wegen 401 verworfen wurden, holt die App nicht automatisch zurück. Der Grund wird nicht gespeichert, ein Zurückholen wäre Raten.
- `completeSession` wird nicht in die Warteschlange gelegt. Der Abschluss blockiert schon heute nicht.

## 1. Einfrieren: messen, dann beheben

### 1a. Messung (erste Etappe, vor allen Fixes)

**Aufbau:**
- Simulator mit dem Network Link Conditioner, Profile „100% Loss“ und „Very Bad Network“.
- Instruments mit dem Template „Hangs“ und dem Time Profiler.

**Abläufe:**
1. Training-Tab öffnen, „Gerät wählen“, in die Suche tippen.
2. Eine Übung mit Erstkontakt öffnen, sodass die Einweisung erscheint.
3. Durch die Liste mit Videokacheln scrollen.

**Ergebnis:** Eine Liste aller Main-Thread-Blocker über 250 ms mit Stacktrace. Sie kommt als Anhang in den Plan. Ursachen, die nicht unter 1b fallen, werden eigene Plan-Etappen.

### 1b. Fixes, die unabhängig von der Messung kommen

- **`Zeitpunkt`:** Die Parser sind statisch und werden wiederverwendet. Der Zugriff ist threadsicher, weil `ISO8601DateFormatter` ab iOS 7 threadsicher ist.
- **Suche:**
  - Das Ergebnis (`gruppen`) wird nicht mehr in jedem `body`-Durchlauf berechnet.
  - Es wird bei Textänderung nach ~150 ms Debounce neu berechnet und in `@State` abgelegt. Bei Änderungen am Bootstrap wird es sofort neu berechnet.
  - `untertitel` nutzt dieselben `stationen` und rechnet sie nicht separat.
- **`Geraetefoto`:**
  - Es dekodiert und verkleinert über `Vorschau.verkleinert` abseits des Main-Threads, auf die Pixel der Anzeigegröße. Das ist derselbe Weg wie beim `VorschauLader`.
  - Auf den Main-Thread kommt nur das fertige `UIImage`.

## 2. Netz-Schicht: schnell scheitern

### Timeouts

- `APIClient` bekommt eine eigene `URLSession` mit `URLSessionConfiguration.default`:
  - `timeoutIntervalForRequest = 10`
  - `waitsForConnectivity = false`
- `Medienablage` bekommt **eine** gemeinsame ephemere Session pro Instanz statt einer neuen pro Download. Sie hat `timeoutIntervalForRequest = 20`.
- Der Token-Refresh von supabase-swift läuft über die eigene Session der Bibliothek. Er bekommt den 10-s-Timeout über den `fetch`-Parameter von `AuthClient`, falls die Version 2.55.1 das anbietet. Das wird bei der Umsetzung geprüft. Bietet sie es nicht an, bleibt der Timeout der Bibliothek, und 4a fängt den Fehler ab.

### Offline sofort scheitern

- `APIClient` bekommt einen `istOnline`-Provider (eine Closure auf `NetzwerkMonitor.istOnline`).
- Meldet der Monitor offline, wirft jeder Request sofort `.offline`, ohne Netzverkehr.
- Der Monitor startet mit `true`. Den ersten Request blockiert er also nie fälschlich.

### Halbes Netz

- Solange `pendingWrites` nicht leer ist, versucht ein Timer in `CatalogStore` alle 30 s `flushPending()`, wenn der Monitor online meldet.
- Der Timer endet, sobald die Warteschlange leer ist.
- Zwei Flushs laufen nie gleichzeitig. Ein laufender Flush wird nicht doppelt gestartet.

### Kaltstart

- Der Spinner in `RootView` zeigt nach 3 s den Text „Verbindung ist langsam …“.
- Mit gespeichertem Bootstrap (3a) gibt es ihn beim Kaltstart gar nicht mehr.

## 3. Offline-Daten

### 3a. Bootstrap wird gespeichert

- Ein neuer `BootstrapFileStore` folgt dem Muster von `VerlaufFileStore`:
  - Er schreibt `bootstrap.json` nach Application Support.
  - Die Datei enthält `{ userId, geladenAm, bootstrap }`.
- **`CatalogStore.load()`:**
  1. Liegt ein gespeicherter Bootstrap für die aktuelle User-ID vor, wird er sofort gesetzt (`loadState = .loaded`).
  2. Danach wird im Hintergrund nachgeladen.
  3. Nach Erfolg wird der neue Bootstrap gesetzt und gespeichert.
  4. Scheitert das Nachladen, bleibt der gespeicherte Bootstrap stehen, ohne Fehlerscreen.
- „NICHT GELADEN“ erscheint nur noch ohne gespeicherten Bootstrap.
- Bei abweichender User-ID wird die Datei ignoriert und überschrieben. Beim Logout wird sie gelöscht.
- Veraltete `lastSets` sind unkritisch. Die lokale Einheit (`WorkoutSessionStore`) kennt die Sätze der laufenden Einheit, und `naechsterSetIndex` liest schon lokal.
- Lässt sich die gespeicherte Datei nicht dekodieren (etwa durch eine Formatänderung), wird sie verworfen. Das Verhalten ist dann wie ohne Cache.

### 3b. Einweisungstext im Bootstrap

- **Server:** `packages/domain/src/bootstrap.ts` gibt pro Übung zusätzlich `description: string | null` aus, für Katalog- und Studio-Übungen.
- **App:** `BootstrapResponse.Exercise.description` ist optional (`String?`), damit alte Server und alte gespeicherte Bootstraps dekodierbar bleiben.
- **`EinweisungSchritt`:** Der Text kommt aus `modell.kontext?…description`, sonst aus dem Bootstrap.
- Die Größenzunahme des Bootstraps wird bei der Umsetzung gemessen. Erwartet werden ~150 KB unkomprimiert.

### 3c. Video und Foto ohne frische URL

- **Video:**
  - `EinweisungSchritt` macht die Videokachel nicht mehr von `aktiveUebung?.videoURL != nil` abhängig.
  - Es fragt `UebungsVideoVorrat.datei(exerciseId:ersatz:)`, mit der Kontext-URL als Ersatz.
  - Ohne Quelle liefert die Medienablage die zuletzt abgelegte Datei zum Schlüssel `exerciseId`.
  - „Einweisungsvideo braucht Empfang.“ erscheint nur, wenn keine Datei gefunden wird.
- **Foto:**
  - `Geraetefoto` nutzt als Schlüssel die Modell-ID, wie die Liste im `VorschauLader`, statt `url.path`.
  - Offline, also ohne URL, findet es so die schon abgelegte Datei über den Index.
  - `Geraetefoto` bekommt dafür einen Parameter `modellId`.

### 3d. Videos vorladen

- Nach einem erfolgreichen `exerciseVideos()` lädt `UebungsVideoVorrat` alle Quellen, deren Datei noch fehlt:
  - nacheinander,
  - mit `Task(priority: .background)`,
  - über Mobilfunk erlaubt.
- Vor jedem Download wird `NetzwerkMonitor.istOnline` geprüft. Offline bricht das Vorladen ab und startet beim nächsten erfolgreichen `exerciseVideos()` neu.
- Es läuft immer nur ein Vorladevorgang gleichzeitig.
- Bereits laufende Downloads derselben Datei werden über `laufend` in der Medienablage geteilt.

## 4. Login und Sätze nicht verlieren

### 4a. Offline-Start ohne Login-Screen

- `SupabaseAuthBackend.currentSession()` unterscheidet zwei Fälle, wenn `client.session` scheitert:
  - **Netzfehler** (`URLError`, Timeout): Die App nimmt die gespeicherte Session `client.currentSession`, auch wenn sie abgelaufen ist.
  - **Auth-Fehler** des Servers (Refresh-Token ungültig oder widerrufen): Das Ergebnis ist `nil`, und es geht wie bisher zum Login.
- Die genaue Fehlertypisierung von supabase-swift 2.55.1 wird bei der Umsetzung geprüft und in einem Test festgehalten.
- **Kaltstart:** `SessionStore.restoreSession()` setzt die Session auch dann, wenn sie abgelaufen ist. Die App zeigt Home oder Training mit dem gespeicherten Bootstrap.

### 4b. Kein Request ohne Token

- Nach 4a kann das Backend offline eine **abgelaufene** Session liefern. `SessionStore.currentAccessToken()` gibt deren Token deshalb nicht weiter: Ist `expiresAt` überschritten, liefert es `nil`. Ein abgelaufener Token würde sonst wieder als 401 zurückkommen.
- Ist ein User angemeldet und es gibt keinen gültigen Token, wirft der `APIClient` `.offline`, ohne Request.
- Requests ohne Login (Anmeldung, Registrierung) sind davon nicht betroffen. Sie gehen nicht über den `tokenProvider`.

### 4c. 401 verwirft keine Sätze

- `flushPending` behandelt `.unauthorized` als vorübergehend. Der Satz bleibt in `pendingWrites`.
- Endgültig verworfen werden weiter `.validation` (422), `.notFound` (404), `.conflict` (409) und `.encodingFailed`.
- `istDauerhaft` selbst bleibt unverändert, weil andere Aufrufer es nutzen. Die Ausnahme steht in `flushPending`. Ob ein anderer Aufrufer dieselbe Ausnahme braucht, wird bei der Umsetzung geprüft.
- Die Warteschlange bleibt über Logout und erneutes Login **desselben** Users erhalten. Sie wird nur gelöscht, wenn sich ein anderer User anmeldet. Das heutige Logout-Verhalten wird bei der Umsetzung geprüft und gegebenenfalls angepasst.

## 5. Tests

Testgetrieben: Für jede Änderung kommt erst ein roter Test, dann die Umsetzung.

### Server

`packages/domain/src/bootstrap.test.ts`:
- `description` erscheint für Katalog- und Studio-Übungen.
- Wo keine gepflegt ist, steht `null`.

### iOS (`apps/ios-member/FitnessMemberTests`)

- **`APIClientTests`:**
  - Ist der Monitor offline, kommt sofort `.offline` und es gibt keinen Request.
  - Angemeldet ohne gültigen Token: kein Request.
  - Die Session-Konfiguration hat einen Timeout von 10 s.
- **`CatalogStoreTests`:**
  - Der Bootstrap wird gespeichert.
  - Beim Start ohne Netz kommt der gespeicherte Bootstrap mit `loadState = .loaded`.
  - Bei fremder User-ID wird die Datei ignoriert.
  - Eine kaputte Datei wird verworfen.
  - 401 in `flushPending`: Der Satz bleibt.
  - 422, 404 und 409: Der Satz wird verworfen.
  - Der Retry-Timer läuft nur bei offenen Einträgen, und es läuft nie mehr als ein Flush gleichzeitig.
- **`AuthLogicTests`** mit Fake-Backend:
  - Netzfehler beim Refresh: Die gespeicherte Session bleibt.
  - Auth-Fehler: Ergebnis `nil`.
- **`GeraetModelTests` / Einweisung:**
  - Ohne Kontext kommt der Text aus dem Bootstrap.
  - Ohne URL kommt das Video aus dem Vorrat, sofern die Datei da ist.
  - Ohne Datei erscheint der Hinweis.
- **Medienablage:**
  - Das Foto wird über die Modell-ID gefunden.
  - Eine gemeinsame Session für alle Downloads.
  - Das Vorladen holt nur fehlende Dateien, nacheinander, und bricht offline ab.
- **`Zeitpunkt`:** Die Ergebnisse sind unverändert, auch nach dem Umbau auf statische Parser.
- **`GeraeteAuswahlTests`:** Die Suchergebnisse sind identisch zu vorher.

### Manuelle Abnahme (Network Link Conditioner, Gerät oder Simulator)

1. **Kaltstart:** Mit „100% Loss“ und abgelaufenem Token (App > 1 h nicht genutzt) sind Home und Training sofort da. Es erscheint kein Login und kein „NICHT GELADEN“.
2. **Suche und Einweisung:** Bei „100% Loss“ und bei „Very Bad Network“ sind Text und Video sichtbar, sofern das Video vorgeladen war. Instruments zeigt keine Hangs über 250 ms.
3. **Sätze:** Drei Sätze offline loggen, dann das Netz wieder an. Alle drei kommen auf dem Server an, und keiner landet in `verworfeneWrites`.
