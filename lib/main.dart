import 'dart:io';

import 'package:flutter/material.dart';
import 'package:android_alarm_manager/android_alarm_manager.dart';
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
  int _alarmID;
  TimeOfDay _time;
  DateTime _alarmTime;
  static AssetsAudioPlayer _audioPlayer = AssetsAudioPlayer();

  @override
  void initState() {
    super.initState();
    _alarmSet = false;
    _alarmID = 0;
    _time = TimeOfDay(hour: 9, minute: 0);
    _updateAlarmTime(); // initialize _alarmTime

    initAsync();
  }

  void initAsync() async {
    await AndroidAlarmManager.initialize();
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
                        content: Text(
                          _formSnackbarContent(alarmToggleState),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                            letterSpacing: 1.1,
                          ),
                        ),
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

    int hour = _time.hour;
    int minute = _time.minute;
    return '${_fixLeadingZero(hour)}:${_fixLeadingZero(minute)}';
  }

  String _fixLeadingZero(int number) {
    return number < 10 ? '0$number' : '$number';
  }

  // TODO: add waitTime (and 'exit'?)
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
      await AndroidAlarmManager.oneShotAt(_alarmTime, _alarmID, _alarm,
          allowWhileIdle: true, exact: true, wakeup: true);
    } else {
      if (_didAlarmStart()) {
        /// Reset volume and stop the player/app
        try {
          await _AlarmSetupState._audioPlayer.setVolume(0.0);
          await _AlarmSetupState._audioPlayer.dispose();
          await _AlarmSetupState._audioPlayer.stop();
        } catch (e) {
          // TODO: replace delay with manual snackbar exit?
          Future.delayed(Duration(seconds: 5), () {
            exit(1);
          });
        }
      } else {
        await AndroidAlarmManager.cancel(_alarmID);
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

  static void _updateVolume() async {
    double volume = 0.0;

    while (volume < 1.0) {
      await Future.delayed(const Duration(seconds: 5), () async {
        // TODO: setup change rate to personal preference
        volume += 0.1;
        await _AlarmSetupState._audioPlayer.setVolume(volume);
        print("Increasing volume to: $volume");
      });
    }

    print("Maximum volume reached!");
  }

  static void _alarm() async {
    /// Start player
    const streamLink = "http://kepler.shoutca.st:8404/";
    try {
      await _AlarmSetupState._audioPlayer.open(Audio.liveStream(streamLink));
      await _AlarmSetupState._audioPlayer.setVolume(0.0);
    } catch (e) {
      /// Use song as a backup
      await _AlarmSetupState._audioPlayer.open(Audio("assets/audio/test.mp3"));
      print("Stream not working.");
    }

    _updateVolume();
  }
}
