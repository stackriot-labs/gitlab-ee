/* eslint-disable func-names, space-before-function-paren, no-var, space-before-blocks, prefer-rest-params, wrap-iife, no-console, quotes, prefer-template, no-undef, padded-blocks, max-len */
(function() {
  var bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  this.U2FError = (function() {
    function U2FError(errorCode) {
      this.errorCode = errorCode;
      this.message = bind(this.message, this);
      this.httpsDisabled = window.location.protocol !== 'https:';
      console.error("U2F Error Code: " + this.errorCode);
    }

    U2FError.prototype.message = function() {
      switch (false) {
        case !(this.errorCode === u2f.ErrorCodes.BAD_REQUEST && this.httpsDisabled):
          return "U2F only works with HTTPS-enabled websites. Contact your administrator for more details.";
        case this.errorCode !== u2f.ErrorCodes.DEVICE_INELIGIBLE:
          return "This device has already been registered with us.";
        default:
          return "There was a problem communicating with your device.";
      }
    };

    return U2FError;

  })();

}).call(this);
