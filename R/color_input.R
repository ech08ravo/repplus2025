# A native <input type="color"> wired up as a Shiny input.
#
# colourpicker would do this too, but it is not in renv.lock and pulling it in
# would mean a new dependency plus a Docker and a shinyapps.io rebuild for one
# control. The browser's own colour picker needs no dependency at all, and it
# is the control the visitor's OS already makes accessible.

colorInput <- function(inputId, label, value = "#000000", width = NULL) {
  tags$div(
    class = "form-group shiny-input-container",
    style = if (!is.null(width)) paste0("width:", width, ";"),
    tags$label(class = "control-label", `for` = inputId, label),
    tags$input(
      id = inputId, type = "color", value = value,
      class = "webgrid-color-input form-control",
      style = "height: 34px; padding: 3px; cursor: pointer;"
    )
  )
}

# Registered once, by colorInputDeps(), which goes in the UI head.
colorInputDeps <- function() {
  tags$head(tags$script(HTML(r"(
    $(function () {
      var binding = new Shiny.InputBinding();
      $.extend(binding, {
        find:      function (scope) { return $(scope).find('input.webgrid-color-input'); },
        getValue:  function (el) { return el.value; },
        setValue:  function (el, value) { el.value = value; },
        subscribe: function (el, callback) {
          // 'input' fires while the picker is dragged, 'change' when it closes;
          // the rate policy below keeps that from redrawing the plot per pixel.
          $(el).on('change.webgridColor input.webgridColor', function () { callback(true); });
        },
        unsubscribe:   function (el) { $(el).off('.webgridColor'); },
        getRatePolicy: function () { return { policy: 'debounce', delay: 200 }; }
      });
      Shiny.inputBindings.register(binding, 'webgrid.colorInput');
    });
  )")))
}
