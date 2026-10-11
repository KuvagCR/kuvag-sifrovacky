
async function saveStationDetail(stationId) {
  if (!state.sessionToken) return false;

  const finishedAt = new Date().toISOString();

  try {
    const response = await fetch(
      SUPABASE_URL + "/rest/v1/rpc/save_station_detail",
      {
        method: "POST",
        headers: {
          apikey: SUPABASE_KEY,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          p_session_token: state.sessionToken,
          p_station_id: stationId,
          p_hints_used: state.stationHints,
          p_wrong_attempts: state.stationWrong,
          p_started_at: state.stationStartedAt,
          p_finished_at: finishedAt,
          p_answer_history: state.stationAnswerHistory || [],
          p_hints_history: state.stationHintsHistory || []
        })
      }
    );

    if (!response.ok) {
      console.error(
        "Detail stanoviště:",
        response.status,
        await response.text()
      );
      return false;
    }

    return true;
  } catch (error) {
    console.error("Detail stanoviště:", error);
    return false;
  }
}

function safeGameText(value) {
  return escHtml(value || "").replace(/\n/g, "<br>");
}

/* ZOBRAZENÍ STANOVIŠTĚ */
station = function () {
  app.className = "card";

  state.hintIndex = 0;
  state.stationHints = 0;
  state.stationWrong = 0;
  state.stationStartedAt = new Date().toISOString();
  state.stationAnswerHistory = [];
  state.stationHintsHistory = [];

  const s = stations[state.i];
  const image = s.image || HERO;
  const isMorseStation = state.i === 4;

  let morseHtml = "";

  if (isMorseStation) {
    const morseLetters = [
      { number: 1, code: "..." },
      { number: 2, code: ".-.." },
      { number: 3, code: "." },
      { number: 4, code: ".--." },
      { number: 5, code: "." },
      { number: 6, code: ".---" },
      { number: 7, code: "." }
    ];

    morseHtml =
      '<div class="morse-puzzle">' +
        '<div class="morse-heading">TAJNÁ ZPRÁVA</div>' +
        '<p class="morse-intro">' +
          'Někdo zanechal zašifrovanou zprávu. ' +
          'Rozlušti jednotlivé znaky Morseovy abecedy v pořadí 1 až 7. ' +
          'Písmena čti rovnou za sebou, bez mezer.' +
        '</p>' +
        '<div class="morse-legend">' +
          '<span><b>●</b> tečka</span>' +
          '<span><b>━</b> čárka</span>' +
        '</div>' +
        '<div class="morse-cards">' +
          morseLetters.map(function (letter) {
            const symbols = letter.code
              .split("")
              .map(function (symbol) {
                return symbol === "."
                  ? '<span class="morse-dot">●</span>'
                  : '<span class="morse-dash">━</span>';
              })
              .join(" ");

            return (
              '<div class="morse-card">' +
                '<span class="morse-number">ZNAK ' +
                  letter.number +
                '</span>' +
                '<span class="morse-code">' +
                  symbols +
                '</span>' +
              '</div>'
            );
          }).join("") +
        '</div>' +
        '<p class="morse-instruction">' +
          'Přečti znaky postupně od 1 do 7 ' +
          'a zadej výsledné slovo do políčka.' +
        '</p>' +
      '</div>';
  }

  app.innerHTML =
    '<div class="eyebrow">Stanoviště ' +
      (state.i + 1) + ' / ' + stations.length +
    '</div>' +

    '<div class="progress">' +
      '<i style="width:' +
        ((state.i + 1) / stations.length * 100) +
      '%"></i>' +
    '</div>' +

    '<h2>' + safeGameText(s.title) + '</h2>' +

    '<img class="station-photo" src="' +
      escHtml(image) +
      '" alt="Fotografie stanoviště">' +

    (
      s.type === "cipher"
        ? '<div class="cipher">' +
            '<div class="cipher-title">ŠIFROVACÍ TABULKA</div>' +
            '<div class="cipher-grid">' +
              Array.from({ length: 26 }, function (_, i) {
                return (
                  '<span><b>' +
                    String.fromCharCode(65 + i) +
                  '</b><small>' +
                    (i + 1) +
                  '</small></span>'
                );
              }).join("") +
            '</div>' +
          '</div>'
        : s.type === "field"
          ? '<div class="field-badge">⌖ ÚKOL V TERÉNU</div>'
          : ''
    ) +

    (
      s.story
        ? '<div class="letter small-letter">' +
            safeGameText(s.story) +
          '</div>'
        : ''
    ) +

    (
      isMorseStation
        ? morseHtml
        : '<div class="task">' +
            safeGameText(s.task) +
          '</div>'
    ) +

    '<input id="answer" placeholder="Tvoje odpověď…" autocomplete="off">' +

    '<button id="check">ZKONTROLOVAT →</button>' +

    '<button id="hint" class="secondary">💡 NÁPOVĚDA</button>' +

    '<div id="hintbox"></div>' +

    '<button id="stationNavigation" class="secondary navigation-station" type="button">' +
      '🧭 NAVIGOVAT K MÍSTU <span>−30 BODŮ</span>' +
    '</button>' +

    '<div id="msg" class="msg"></div>';

  const img = document.querySelector(".station-photo");

  if (img) {
    img.onerror = function () {
      img.onerror = null;
      img.src = HERO;
    };
  }

  document.querySelector("#check").onclick = check;

  document.querySelector("#answer").onkeydown = function (event) {
    if (event.key === "Enter") check();
  };

  document.querySelector("#hint").onclick = hint;

  document.querySelector("#stationNavigation").onclick =
    openNavigation;

  const mapBtn = document.querySelector("#cityMapButton");

  if (mapBtn) {
    mapBtn.hidden = false;
    mapBtn.style.display = "inline-block";
  }
};

/* NÁPOVĚDA */
hint = function () {
  const s = stations[state.i];
  const box = document.querySelector("#hintbox");

  if (state.hintIndex >= s.hints.length) {
    box.innerHTML =
      '<div class="hint">Další nápověda už není.</div>';
    return;
  }

  const hintNumber = state.hintIndex + 1;
  const hintText = s.hints[state.hintIndex];

  state.hints++;
  state.stationHints++;

  state.score = Math.max(
    0,
    state.score - (state.hintIndex ? 20 : 10)
  );

  state.stationHintsHistory.push({
    hint: hintNumber,
    text: hintText,
    used_at: new Date().toISOString()
  });

  state.hintIndex++;

  box.innerHTML =
    '<div class="hint">💡 ' +
    safeGameText(hintText) +
    '</div>';
};

/* KONTROLA ODPOVĚDI */
check = async function () {
  const input = document.querySelector("#answer");
  const val = input.value;
  const s = stations[state.i];
  const msg = document.querySelector("#msg");
  const btn = document.querySelector("#check");

  if (!val.trim() || btn.disabled) return;

  btn.disabled = true;
  btn.textContent = "KONTROLUJI…";

  let result;

  try {
    result = await checkStationAnswer(s.id, val);
  } catch (error) {
    console.error("Kontrola odpovědi:", error);
    result = { ok: false };
  }

  if (!result.ok) {
    btn.disabled = false;
    btn.textContent = "ZKONTROLOVAT →";

    msg.className = "msg bad";
    msg.textContent =
      "Odpověď se nepodařilo ověřit. Zkontroluj připojení a zkus to znovu.";

    return;
  }

  const morseAnswer = state.i === 4 &&
    String(val || "")
      .normalize("NFD")
      .replace(/[\\u0300-\\u036f]/g, "")
      .replace(/[^A-Z]/gi, "")
      .toUpperCase() === "SLEPEJE";
  const isCorrect = !!result.correct || morseAnswer;

  state.stationAnswerHistory.push({
    answer: val.trim(),
    correct: isCorrect,
    answered_at: new Date().toISOString()
  });

  if (isCorrect) {
    msg.className = "msg ok";
    msg.textContent =
      "✓ Správně! Získáváš přístup k další stopě.";

    const saved = await saveStationDetail(s.id);

    if (!saved) {
      btn.disabled = false;
      btn.textContent = "ZKONTROLOVAT →";

      msg.className = "msg bad";
      msg.textContent =
        "Odpověď je správně, ale výsledek se nepodařilo uložit. " +
        "Zkontroluj připojení a stiskni ZKONTROLOVAT znovu.";

      state.stationAnswerHistory.pop();
      return;
    }

    setTimeout(function () {
      reveal();
    }, 750);

  } else {
    state.wrong++;
    state.stationWrong++;

    state.score = Math.max(0, state.score - 5);

    btn.disabled = false;
    btn.textContent = "ZKONTROLOVAT →";

    msg.className = "msg bad";
    msg.textContent = "To není správný klíč. Zkus to znovu.";

    input.select();
  }
};
