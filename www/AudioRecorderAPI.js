function AudioRecorderAPI() {
}

AudioRecorderAPI.prototype.record = function (successCallback, errorCallback, duration, name) {
  cordova.exec(successCallback, errorCallback, "AudioRecorderAPI", "record", duration ? [duration, name] : [name]);
};

AudioRecorderAPI.prototype.stop = function (successCallback, errorCallback) {
  cordova.exec(successCallback, errorCallback, "AudioRecorderAPI", "stop", []);
};

AudioRecorderAPI.prototype.playback = function (successCallback, errorCallback, name) {
  cordova.exec(successCallback, errorCallback, "AudioRecorderAPI", "playback", [name]);
};

AudioRecorderAPI.prototype.deleteLast = function (successCallback, errorCallback, name) {
  cordova.exec (successCallback, errorCallback, "AudioRecorderAPI", "deleteLastRecord", [name]);
};

AudioRecorderAPI.install = function () {
  if (!window.plugins) {
    window.plugins = {};
  }
  window.plugins.audioRecorderAPI = new AudioRecorderAPI();
  return window.plugins.audioRecorderAPI;
};

cordova.addConstructor(AudioRecorderAPI.install);
