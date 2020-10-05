import 'dart:io';

import 'package:flutter/material.dart';
import 'package:background_fetch/background_fetch.dart';
import 'package:assets_audio_player/assets_audio_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProgressiveAlarm());
}

class ProgressiveAlarm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Progressive Alarm',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AlarmSetup(),
    );
  }
}

class AlarmSetup extends StatefulWidget {
  @override
  _AlarmSetupState createState() => _AlarmSetupState();
}

class _AlarmSetupState extends State<AlarmSetup> {
  bool _alarmSet;
  bool _alarmRunning;
  String _taskID;
  TimeOfDay _time;
  DateTime _alarmTime;
  // type is TimeOfDay for easier display
  TimeOfDay _timeRemaining;
  AssetsAudioPlayer _audioPlayer = AssetsAudioPlayer();

  @override
  void initState() {
    super.initState();
    _alarmSet = false;
    _alarmRunning = false;
    _taskID = 'com.progressive_alarm.alarm';
    _time = TimeOfDay(hour: 9, minute: 0);
    _determineTimeRemaining();
    _updateAlarmTime(); // initialize _alarmTime

    initAsync();
  }

  void initAsync() async {
    BackgroundFetch.configure(
        BackgroundFetchConfig(
            minimumFetchInterval: 15,
            stopOnTerminate: false,
            startOnBoot: true,
            enableHeadless: true), (String taskId) {
      if (_didAlarmStart()) {
        _alarm();
      }
      BackgroundFetch.finish(taskId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text('⏰\t\tProgressive Alarm\t\t⏰')),
      ),
      body: Builder(builder: (BuildContext context) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              OutlineButton(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: EdgeInsets.symmetric(vertical: 20, horizontal: 50),
                  color: Colors.transparent,
                  textColor: Colors.blue,
                  child: Text(
                    '${_formatTime()}',
                    style: TextStyle(fontSize: 46),
                  ),
                  onPressed: () async {
                    TimeOfDay chosenTime = await showTimePicker(
                        context: context, initialTime: TimeOfDay.now());
                    if (chosenTime != null) {
                      setState(() {
                        _time = chosenTime;
                      });

                      _updateAlarmTime();
                    }
                  }),
              Container(
                child: _alarmSet
                    ? Text(
                        '${_formatTime(time: _timeRemaining)}',
                        style: TextStyle(color: Colors.black),
                      )
                    : null,
                margin: EdgeInsets.only(top: 20),
              ),
              SizedBox(height: 100),
              Container(
                child: Text(
                  'Toggle alarm',
                  style: TextStyle(fontSize: 16),
                ),
                height: 30,
              ),
              Transform.scale(
                scale: 2.0,
                child: Switch(
                  value: _alarmSet,
                  onChanged: (bool alarmToggleState) {
                    Scaffold.of(context).showSnackBar(
                      SnackBar(
                        duration: !alarmToggleState && _didAlarmStart()
                            ? Duration(seconds: 10)
                            : Duration(seconds: 4),
                        content: Text(
                          _formSnackbarContent(alarmToggleState),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 20.0,
                              fontWeight: FontWeight.bold,
                              height: 1.5,
                              letterSpacing: 1.1,
                              color: Colors.white),
                        ),
                        action: !alarmToggleState && _didAlarmStart()
                            ? SnackBarAction(
                                label: "Exit",
                                onPressed: () => {exit(1)},
                                textColor: Colors.white,
                              )
                            : null,
                        backgroundColor: Colors.blue,
                      ),
                    );

                    _updateAlarmState(alarmToggleState);
                  },
                ),
              )
            ],
          ),
        );
      }),
    );
  }

  String _formatTime({TimeOfDay time}) {
    /// Use alarm time as default value
    time = time ?? _time;

    int hour = time.hour;
    int minute = time.minute;
    return '${_fixLeadingZero(hour)}:${_fixLeadingZero(minute)}';
  }

  String _fixLeadingZero(int number) {
    return number < 10 ? '0$number' : '$number';
  }

  void _determineTimeRemaining() {
    TimeOfDay now = TimeOfDay.now();
    int alarmInMinutes = _time.hour * 60 + _time.minute;
    int nowInMinutes = now.hour * 60 + now.minute;
    int remainingInMinutes = alarmInMinutes - nowInMinutes;
    if (nowInMinutes > alarmInMinutes) {
      remainingInMinutes += 1440;
    }

    int remainingHours = remainingInMinutes ~/ 60;
    int remainingMinutes = remainingInMinutes - (remainingHours * 60);

    setState(() {
      _timeRemaining =
          TimeOfDay(hour: remainingHours, minute: remainingMinutes);
    });
  }

  String _formSnackbarContent(bool alarmToggleState) {
    if (alarmToggleState) {
      return 'Alarm set for ${_formatTime()}!';
    }

    if (_didAlarmStart()) {
      return 'Alarm stopped!';
    }

    return 'Alarm canceled!';
  }

  void _updateAlarmState(bool startAlarm) async {
    if (startAlarm) {
      BackgroundFetch.scheduleTask(TaskConfig(
          taskId: _taskID,
          delay: _alarmTime.difference(DateTime.now()).inMilliseconds,
          periodic: false));
      _determineTimeRemaining();
    } else {
      _alarmRunning = false;
      BackgroundFetch.stop(_taskID);

      if (_didAlarmStart()) {
        /// Reset volume and stop the player/app
        try {
          await _audioPlayer.setVolume(0.0);
          await _audioPlayer.stop();
          await _audioPlayer.dispose();
        } catch (e) {
          Future.delayed(Duration(seconds: 3), () {
            exit(1);
          });
        }
      }
    }

    setState(() {
      _alarmSet = startAlarm;
    });
  }

  bool _didAlarmStart() {
    DateTime now = DateTime.now();
    return !(now.day < _alarmTime.day ||
        now.hour < _alarmTime.hour ||
        now.minute < _alarmTime.minute);
  }

  void _updateAlarmTime() {
    DateTime now = DateTime.now();
    DateTime alarmTime = new DateTime(
        now.year,
        now.month,
        (_time.hour < now.hour ||
                _time.hour == now.hour && _time.minute < now.minute)
            ? (now.day + 1)
            : now.day,
        _time.hour,
        _time.minute);

    setState(() {
      _alarmTime = alarmTime;
      _alarmSet = false;
    });
  }

  void _updateVolume() async {
    double volume = 0.0;

    while (volume < 1.0) {
      if (!_alarmRunning) return;

      await Future.delayed(const Duration(seconds: 5), () async {
        volume += 0.1;
        await _audioPlayer.setVolume(volume);
        print("Increasing volume to: $volume");
      });
    }

    print("Maximum volume reached!");
  }

  void _alarm() async {
    _alarmRunning = true;

    /// Start player
    const streamLink = "http://kepler.shoutca.st:8404/";
    try {
      await _audioPlayer.open(Audio.liveStream(streamLink));
      await _audioPlayer.setVolume(0.0);
    } catch (e) {
      /// Use song as a backup
      await _audioPlayer.open(Audio("assets/audio/test.mp3"));
      print("Stream not working.");
    }

    _updateVolume();
  }
}
