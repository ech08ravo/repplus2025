# Visitor-facing display preferences.
#
# This is a preferences panel, not an "accessibility overlay". It changes only
# what the visitor asks it to change and remembers the choice; it does not try
# to detect or auto-repair the page. Overlays that do that are widely held to
# make matters worse, and they are no substitute for the page being built
# correctly in the first place.
#
# Everything here is client side. Nothing is sent to the server and nothing is
# recorded about the visitor - the choices live in their own browser only.
#
# Note on text size: every font-size in this app is set in px, so scaling the
# root font size would do nothing. zoom is what actually works on a px-based
# layout. It scales the HTML interface; the text drawn inside the plots is a
# separate matter, which the sidebar's own "Text Size" slider controls.

A11Y_STEPS <- c(100, 115, 130, 150)

accessibility_widget <- function() {
  tagList(
    tags$head(
      tags$style(HTML(accessibility_css())),
      # Applied before first paint so a returning visitor does not see the
      # default styling flash past before their preferences land.
      tags$script(HTML(accessibility_boot_js()))
    ),

    tags$button(
      id = "a11y-launcher", type = "button", class = "a11y-launcher",
      `aria-label` = "Display options",
      `aria-expanded` = "false", `aria-controls` = "a11y-panel",
      HTML("&#9728;")
    ),

    tags$div(
      id = "a11y-panel", class = "a11y-panel", role = "dialog",
      `aria-labelledby` = "a11y-panel-title", hidden = NA,

      tags$div(
        class = "a11y-panel-head",
        tags$h2(id = "a11y-panel-title", "Display options"),
        tags$button(id = "a11y-close", type = "button", class = "a11y-close",
                    `aria-label` = "Close display options", HTML("&times;"))
      ),

      tags$div(
        class = "a11y-group",
        tags$span(id = "a11y-text-label", class = "a11y-group-label", "Text size"),
        tags$div(
          class = "a11y-steps", role = "group", `aria-labelledby` = "a11y-text-label",
          lapply(seq_along(A11Y_STEPS), function(i) {
            pc <- A11Y_STEPS[i]
            tags$button(
              type = "button", class = "a11y-step", `data-size` = pc,
              `aria-pressed` = if (i == 1) "true" else "false",
              paste0(pc, "%")
            )
          })
        )
      ),

      tags$div(
        class = "a11y-group",
        tags$span(class = "a11y-group-label", "Presentation"),
        a11y_switch("contrast",  "High contrast",
                    "Dark background with light text and firmer borders."),
        a11y_switch("underline", "Underline links",
                    "Marks links by more than colour alone."),
        a11y_switch("readable",  "Readable font",
                    "A plainer typeface with looser letter and line spacing."),
        a11y_switch("motion",    "Reduce motion",
                    "Stops sliding panels and other animation.")
      ),

      tags$div(
        class = "a11y-group a11y-foot",
        tags$button(id = "a11y-reset", type = "button", class = "a11y-reset",
                    "Reset to defaults"),
        tags$p(class = "a11y-note",
               "Saved in this browser only. Text inside the plots is set by the",
               tags$strong("Text Size"), "slider in the control panel.")
      )
    ),

    tags$script(HTML(accessibility_js()))
  )
}

# One labelled on/off control. A real <button> with aria-pressed, so it is
# reachable by keyboard and announced as a toggle.
a11y_switch <- function(key, label, hint) {
  tags$button(
    type = "button", class = "a11y-switch", `data-flag` = key,
    `aria-pressed` = "false",
    tags$span(class = "a11y-switch-box", `aria-hidden` = "true"),
    tags$span(
      class = "a11y-switch-text",
      tags$span(class = "a11y-switch-label", label),
      tags$span(class = "a11y-switch-hint", hint)
    )
  )
}

accessibility_boot_js <- function() {
  r"(
  (function () {
    try {
      var saved = JSON.parse(localStorage.getItem('webgrid-a11y') || '{}');
      var el = document.documentElement;
      if (saved.size && saved.size !== 100) el.setAttribute('data-a11y-size', saved.size);
      ['contrast', 'underline', 'readable', 'motion'].forEach(function (f) {
        if (saved[f]) el.setAttribute('data-a11y-' + f, 'on');
      });
    } catch (e) { /* private mode, blocked storage - defaults are fine */ }
  })();
  )"
}

accessibility_css <- function() {
  r"(
  /* --- launcher + panel ------------------------------------------------- */
  .a11y-launcher {
    position: fixed; bottom: 16px; left: 16px; z-index: 1000;
    width: 48px; height: 48px; border-radius: 50%;
    border: 2px solid #fff; background: #0072B2; color: #fff;
    font-size: 22px; line-height: 1; cursor: pointer;
    box-shadow: 0 2px 8px rgba(0,0,0,0.3);
  }
  .a11y-launcher:hover { background: #005a8e; }
  .a11y-launcher:focus-visible, .a11y-panel button:focus-visible {
    outline: 3px solid #E69F00; outline-offset: 2px;
  }
  .a11y-panel {
    position: fixed; bottom: 76px; left: 16px; z-index: 1001;
    width: 320px; max-width: calc(100vw - 32px);
    max-height: calc(100vh - 100px); overflow-y: auto;
    background: #fff; color: #222;
    border: 1px solid #bbb; border-radius: 8px;
    box-shadow: 0 4px 20px rgba(0,0,0,0.25); padding: 14px;
  }
  .a11y-panel[hidden] { display: none; }
  .a11y-panel-head { display: flex; align-items: center; justify-content: space-between; }
  .a11y-panel h2 { font-size: 16px; margin: 0 0 4px; }
  .a11y-close {
    border: none; background: none; font-size: 22px; line-height: 1;
    cursor: pointer; color: #555; padding: 0 4px;
  }
  .a11y-group { border-top: 1px solid #eee; margin-top: 10px; padding-top: 10px; }
  .a11y-group-label { display: block; font-size: 12px; font-weight: 700;
    text-transform: uppercase; letter-spacing: .04em; color: #666; margin-bottom: 6px; }
  .a11y-steps { display: flex; gap: 6px; }
  .a11y-step {
    flex: 1; padding: 7px 0; font-size: 13px; cursor: pointer;
    border: 1px solid #bbb; border-radius: 5px; background: #f7f7f7; color: #222;
  }
  .a11y-step[aria-pressed="true"] { background: #0072B2; border-color: #0072B2; color: #fff; font-weight: 700; }
  .a11y-switch {
    display: flex; gap: 10px; align-items: flex-start; width: 100%;
    text-align: left; background: none; border: none;
    padding: 7px 4px; cursor: pointer; border-radius: 5px; color: inherit;
  }
  .a11y-switch:hover { background: #f2f7fb; }
  .a11y-switch-box {
    flex: 0 0 auto; width: 36px; height: 20px; margin-top: 2px;
    border-radius: 10px; background: #c4c4c4; position: relative;
    transition: background .15s;
  }
  .a11y-switch-box::after {
    content: ""; position: absolute; top: 2px; left: 2px;
    width: 16px; height: 16px; border-radius: 50%; background: #fff;
    transition: transform .15s;
  }
  .a11y-switch[aria-pressed="true"] .a11y-switch-box { background: #0072B2; }
  .a11y-switch[aria-pressed="true"] .a11y-switch-box::after { transform: translateX(16px); }
  .a11y-switch-text { display: flex; flex-direction: column; }
  .a11y-switch-label { font-size: 13px; font-weight: 600; }
  .a11y-switch-hint { font-size: 11px; color: #666; }
  .a11y-reset {
    width: 100%; padding: 7px; font-size: 13px; cursor: pointer;
    border: 1px solid #bbb; border-radius: 5px; background: #f7f7f7; color: #222;
  }
  .a11y-note { font-size: 11px; color: #666; margin: 8px 0 0; }

  /* --- what the preferences actually do --------------------------------- */
  html[data-a11y-size="115"] body { zoom: 1.15; }
  html[data-a11y-size="130"] body { zoom: 1.30; }
  html[data-a11y-size="150"] body { zoom: 1.50; }

  html[data-a11y-underline] a { text-decoration: underline !important; }

  html[data-a11y-readable] body,
  html[data-a11y-readable] .a11y-panel {
    font-family: Verdana, "DejaVu Sans", Tahoma, sans-serif !important;
    letter-spacing: .02em; line-height: 1.7;
  }

  /* Honour the visitor's own system setting as well as our switch. */
  @media (prefers-reduced-motion: reduce) {
    *, *::before, *::after {
      animation-duration: .001ms !important; animation-iteration-count: 1 !important;
      transition-duration: .001ms !important; scroll-behavior: auto !important;
    }
  }
  html[data-a11y-motion] *, html[data-a11y-motion] *::before, html[data-a11y-motion] *::after {
    animation-duration: .001ms !important; animation-iteration-count: 1 !important;
    transition-duration: .001ms !important; scroll-behavior: auto !important;
  }

  /* High contrast. Plots are images drawn by R, so they keep their own
     colours - the palette selectors on each tab cover those. */
  html[data-a11y-contrast] body,
  html[data-a11y-contrast] .well,
  html[data-a11y-contrast] .tab-content,
  html[data-a11y-contrast] .panel,
  html[data-a11y-contrast] .modal-content { background: #000 !important; color: #fff !important; }
  html[data-a11y-contrast] h1, html[data-a11y-contrast] h2,
  html[data-a11y-contrast] h3, html[data-a11y-contrast] h4,
  html[data-a11y-contrast] h5, html[data-a11y-contrast] p,
  html[data-a11y-contrast] li, html[data-a11y-contrast] td,
  html[data-a11y-contrast] th, html[data-a11y-contrast] label,
  html[data-a11y-contrast] span, html[data-a11y-contrast] div { color: #fff !important; }
  html[data-a11y-contrast] a { color: #7FD4FF !important; }
  html[data-a11y-contrast] .btn,
  html[data-a11y-contrast] input, html[data-a11y-contrast] select,
  html[data-a11y-contrast] textarea {
    background: #111 !important; color: #fff !important; border: 1px solid #fff !important;
  }
  html[data-a11y-contrast] .nav-tabs > li > a { background: #111 !important; border-color: #fff !important; }
  html[data-a11y-contrast] .nav-tabs > li.active > a { background: #0072B2 !important; }
  html[data-a11y-contrast] .a11y-panel { background: #000 !important; border-color: #fff !important; }
  html[data-a11y-contrast] .a11y-step,
  html[data-a11y-contrast] .a11y-reset { background: #111 !important; color: #fff !important; border-color: #fff !important; }
  )"
}

accessibility_js <- function() {
  r"(
  document.addEventListener('DOMContentLoaded', function () {
    var root     = document.documentElement;
    var launcher = document.getElementById('a11y-launcher');
    var panel    = document.getElementById('a11y-panel');
    var closeBtn = document.getElementById('a11y-close');
    var resetBtn = document.getElementById('a11y-reset');
    if (!launcher || !panel) return;

    var FLAGS = ['contrast', 'underline', 'readable', 'motion'];
    var state = { size: 100 };
    try { state = Object.assign(state, JSON.parse(localStorage.getItem('webgrid-a11y') || '{}')); }
    catch (e) { /* storage unavailable - carry on with defaults */ }

    function save() {
      try { localStorage.setItem('webgrid-a11y', JSON.stringify(state)); }
      catch (e) { /* nothing we can do, and nothing that should break the page */ }
    }

    function apply() {
      if (state.size && state.size !== 100) root.setAttribute('data-a11y-size', state.size);
      else root.removeAttribute('data-a11y-size');

      FLAGS.forEach(function (f) {
        if (state[f]) root.setAttribute('data-a11y-' + f, 'on');
        else root.removeAttribute('data-a11y-' + f);
      });

      panel.querySelectorAll('.a11y-step').forEach(function (b) {
        b.setAttribute('aria-pressed', String(Number(b.dataset.size) === Number(state.size || 100)));
      });
      panel.querySelectorAll('.a11y-switch').forEach(function (b) {
        b.setAttribute('aria-pressed', String(!!state[b.dataset.flag]));
      });
    }

    function openPanel() {
      panel.hidden = false;
      launcher.setAttribute('aria-expanded', 'true');
      var first = panel.querySelector('button');
      if (first) first.focus();
    }
    function closePanel(refocus) {
      panel.hidden = true;
      launcher.setAttribute('aria-expanded', 'false');
      if (refocus) launcher.focus();
    }

    launcher.addEventListener('click', function () {
      panel.hidden ? openPanel() : closePanel(true);
    });
    if (closeBtn) closeBtn.addEventListener('click', function () { closePanel(true); });

    panel.querySelectorAll('.a11y-step').forEach(function (b) {
      b.addEventListener('click', function () {
        state.size = Number(b.dataset.size); apply(); save();
      });
    });
    panel.querySelectorAll('.a11y-switch').forEach(function (b) {
      b.addEventListener('click', function () {
        var f = b.dataset.flag; state[f] = !state[f]; apply(); save();
      });
    });
    if (resetBtn) resetBtn.addEventListener('click', function () {
      state = { size: 100 }; apply(); save();
    });

    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && !panel.hidden) closePanel(true);
    });
    document.addEventListener('click', function (e) {
      if (!panel.hidden && !panel.contains(e.target) && e.target !== launcher) closePanel(false);
    });

    apply();
  });
  )"
}
