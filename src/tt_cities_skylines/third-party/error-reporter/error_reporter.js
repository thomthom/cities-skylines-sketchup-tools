/*******************************************************************************
 *
 * Thomas Thomassen
 * thomas[at]thomthom[dot]net
 *
 ******************************************************************************/


window.onerror = function(message, location, line_number) {
  //debugger;
  alert(message + "\n\n" + location + "\n\nLine: " + line_number);
}


/*******************************************************************************
 *
 * module UI
 *
 ******************************************************************************/


var UI = function() {
  return {

    /* Ensure links are opened in the default browser. This ensures that the
     * WebDialog doesn't replace the content with the target URL.
     */
    redirect_links : function() {
      $(document).on('click', 'a[href]', function()
      {
        // Detect skp: actions and don't intercept them.
        if (this.href.indexOf("skp:") != 0) {
          Sketchup.callback("open_url", { url: this.href });
          return false;
        }
      });
    },


    /* Disables text selection on elements other than input type elements where
     * it makes sense to allow selections. This mimics native windows.
     */
    disable_select : function() {
      $(document).on('mousedown selectstart', function(e) {
        return $(e.target).is('input, textarea, select, option');
      });
    },

    enable_select : function() {
      $(document).off('mousedown selectstart');
    },


    /* Disables the context menu with the exception for textboxes in order to
     * mimic native windows.
     */
    disable_context_menu : function() {
      $(document).on('contextmenu', function(e) {
        return $(e.target).is('input[type=text], textarea');
      });
    },

    enable_context_menu : function() {
      $(document).off('contextmenu');
    }

  };

}(); // UI


/*******************************************************************************
 *
 * module Sketchup
 *
 ******************************************************************************/


var Sketchup = function() {
  return {

    callback : function(event_name, data) {
      // Defer with a timer in order to allow the UI to update.
      setTimeout(function() {
        Bridge.set_data(data);
        window.location = "skp:callback@" + event_name;
      }, 0);
    }

  };

}(); // UI


/*******************************************************************************
 *
 * module Bridge
 *
 ******************************************************************************/


var Bridge = function() {
  return {

    // Creates a hidden textarea element used to pass data from JavaScript to
    // Ruby. Ruby calls UI::WebDialog.get_element_value to fetch the content and
    // parse it as JSON.
    // This avoids many issues in regard to transferring data:
    // * Data can be any size.
    // * Avoid string encoding issues.
    // * Avoid evaluation bug in SketchUp when the string has a single quote.
    init : function() {
      var $bridge = $("<textarea id='SU_BRIDGE'></textarea>");
      $bridge.hide();
      $("body").append($bridge);
    },


    set_data : function(data) {
      var $bridge = $("#SU_BRIDGE");
      $bridge.text("");
      if (data !== undefined) {
        try {
          var json = JSON.stringify(data);
        } catch(exception) {
          var json = Bridge.fallback_json_stringify(data);
        }
        $bridge.text(json);
      }
    },


    fallback_json_stringify : function(data) {
      // Unfortunatly we're still stuck with some installations of IE7 and IE6
      // that cause problems. This is a very naive fallback for these versions.
      var json = [];
      $.each(data, function(key, value) {
        escaped_key   = key.replace(/"/g, '\\"');
        escaped_value = value.replace(/"/g, '\\"');
        json.push('"' + escaped_key + '": "' + escaped_value + '"' );
      });
      return '{' + json.join(', ') + '}';
    }

  };

}(); // UI


/*******************************************************************************
 *
 * Error Reporter
 *
 ******************************************************************************/


// http://stackoverflow.com/a/27064127/486990
// The web service that answers these calls also responds with
// 'Access-Control-Allow-Origin: *' header.
$.support.cors = true;

var error_data_;


function setup_error_data(error_data)
{
  error_data_ = error_data;

  // Process the configuration.

  var $more_help = $("#more_help");
  var has_support_url = "config" in error_data_ &&
    "support_url" in error_data_.config &&
    error_data_.config.support_url !== undefined &&
    error_data_.config.support_url !== null;
  if (has_support_url) {
    $more_help.attr("href", error_data_.config.support_url);
  } else {
    $more_help.hide();
  }

  if (error_data_.config.debug) {
    UI.enable_select();
    UI.enable_context_menu();
  }
}


function prepare_error_data(error_data)
{
  // Make a copy of the error data.
  var data = {};
  $.extend(data, error_data);
  // Removed properties not need by the server side.
  delete data.config;
  // Append user information.
  data.user = {
    name: $("#user_name").val(),
    email: $("#user_email").val(),
    description: $("#user_description").val()
  }
  return data;
}


function save_and_close()
{
  var data = {
    name:  $("#user_name").val(),
    email: $("#user_email").val()
  };
  Sketchup.callback("save_and_close", data);
}


function restore_form(data)
{
  $("#user_name").val(data.user_name);
  $("#user_email").val(data.user_email);
}


function action_button()
{
  if ($("#submit").text() == "Close") {
    save_and_close();
  } else {
    submit_error_report();
  }
}


function submit_error_report()
{
  var data = prepare_error_data(error_data_);
  $.ajax({
    type: "POST",
    cache: false,
    url: error_data_.config.server,
    data: data
  })
  .done(function(response, status, xhr) {
    display_response(xhr, status);
    display_close_button();
  })
  .fail(function(xhr, status, errorThrown) {
    display_response(xhr, status);
    $("#submit").prop("disabled", false);
  });

  disable_form();
  display_loader();

  return false;
}


function display_loader()
{
  $("#response").detach();

  var $message = $("<div/>");
  $message.attr("id", "response");
  $message.addClass("info_panel");

  var $status = $("<div />");
  $status.addClass("status")

  var $load_indicator = $("<img />");
  $load_indicator.attr("src", "loading.gif");
  $status.append($load_indicator);

  $status.append($("<p>Sending report...</p>"));

  $message.append($status);

  $("body").append($message);
}


function display_close_button()
{
  $("#submit").text("Close");
  $("#submit").prop("disabled", false);
}


function display_response(xhr, status)
{
  var http_code = xhr.status;

  try {
    var json = jQuery.parseJSON(xhr.responseText);
    var message = json.message;
  } catch(exception) {
    var message = "Unexpected error. Please try again. If the problem \
      persist then please contact the developer.";
  }

  var title = "Error Report Submitted";
  var type = "success";
  if (http_code != 200) {
    title = "Failed to Submit Error Report";
    type = "error";
    message = "<p><b>Error Code:</b> " + http_code + "</p>" + message;
  }

  var $title = $("<h2>" + title + "</h2>");
  $title.addClass(type);

  var $response = $("<div class='response' />").html(message);

  var $message = $("#response");
  $message.text("");

  $message.append($title)
  $message.append($("<hr/>"))
  $message.append($response);
}


function toggle_privacy_info()
{
  var $dialog = $("#privacy_info");
  if ($dialog.length == 0) {
    $dialog = $("<div id='privacy_info' />");
    $dialog.addClass("info_panel");
    var message = "\
      <h2>What info is sent?</h2>\
      \
      <p>When the data is reported it includes the Ruby error \
      data, Extension version, Ruby platform information, SketchUp version \
      information and a list of loaded Ruby features. This is used to provide \
      context to the error.</p>\
      \
      <p>Additionally the user can provide contact information so the \
      developer can respond back to the user.</p>\
      \
      <p>Users are encouraged to fill out the description text field with \
      additional information that might help the developer reproduce the \
      error.</p>";
    $dialog.html(message);
    $dialog.on("click", toggle_privacy_info);
    $dialog.hide();
    $("body").append($dialog);
  }
  $dialog.fadeToggle("fast");
  return false;
}


function disable_form() {
  $("input, textarea, button").prop("disabled", true);
}


function enable_form() {
  $("input, textarea, button").prop("disabled", false);
}


$(document).ready(function() {
  Bridge.init();

  UI.disable_select();
  UI.disable_context_menu();
  UI.redirect_links();

  $("#privacy_link").on("click", toggle_privacy_info);
  $("#submit").on("click", action_button);

  Sketchup.callback("dialog_ready");
});
