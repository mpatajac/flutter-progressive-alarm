import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:background_fetch/background_fetch.dart';
import 'package:assets_audio_player/assets_audio_player.dart';

enum VolumeIncreaseRate { Speeding, Constant, Slowing }

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
  String _taskID;
  TimeOfDay _time;
  DateTime _alarmTime;
  int _alarmDuration;
  VolumeIncreaseRate _volumeIncreaseRate;
  AssetsAudioPlayer _audioPlayer = AssetsAudioPlayer();

  @override
  void initState() {
    super.initState();
    _alarmSet = false;
    _taskID = 'com.progressive_alarm.alarm';
    _time = TimeOfDay(hour: 9, minute: 0);
    _alarmDuration = 5;
    _volumeIncreaseRate = VolumeIncreaseRate.Constant;
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
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              SizedBox(height: 40),
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
              SizedBox(height: 50),
              Container(
                child: Text(
                  'Alarm increase rate',
                  style: TextStyle(fontSize: 16),
                ),
                height: 30,
              ),
              DropdownButton(
                value: _volumeIncreaseRate,
                items: [
                  DropdownMenuItem(
                    child: Text("Start slow, gradualy speed up"),
                    value: VolumeIncreaseRate.Speeding,
                  ),
                  DropdownMenuItem(
                    child: Text("Keep constant rate"),
                    value: VolumeIncreaseRate.Constant,
                  ),
                  DropdownMenuItem(
                    child: Text("Start fast, gradualy slow down"),
                    value: VolumeIncreaseRate.Slowing,
                  ),
                ],
                onChanged: (VolumeIncreaseRate vir) =>
                    _updateVolumeIncreaseRate(vir),
                icon: Icon(Icons.show_chart),
              ),
              SizedBox(height: 50),
              Container(
                child: Text(
                  'Alarm duration (in minutes)',
                  style: TextStyle(fontSize: 16),
                ),
                height: 30,
              ),
              Slider(
                min: 1,
                max: 10,
                divisions: 9,
                value: _alarmDuration.toDouble(),
                onChanged: (value) => _updateAlarmDuration(value.toInt()),
                label: _alarmDuration.toString(),
              ),
              Wrap(
                children: [
                  Text("1"),
                  Text("10"),
                ],
                spacing: MediaQuery.of(context).size.width - 75,
              ),
              SizedBox(height: 40),
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
      BackgroundFetch.scheduleTask(TaskConfig(
          taskId: _taskID,
          delay: _alarmTime.difference(DateTime.now()).inMilliseconds,
          periodic: false));
    } else {
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

  // TODO: refactor
  bool _didAlarmStart() {
    DateTime now = DateTime.now();
    if (now.day < _alarmTime.day) {
      return false;
    }
    if (now.hour < _alarmTime.hour) {
      return false;
    }
    if (now.minute < _alarmTime.minute) {
      return false;
    }
    return true;
  }

  // TODO: fix
  void _updateAlarmTime() {
    DateTime now = DateTime.now();
    DateTime alarmTime = new DateTime(
        now.year,
        now.month,
        _time.hour >= now.hour ? now.day : (now.day + 1),
        _time.hour,
        _time.minute);

    setState(() {
      _alarmTime = alarmTime;
      _alarmSet = false;
    });
  }

  void _updateAlarmDuration(int duration) {
    print(duration);

    setState(() {
      _alarmDuration = duration;
      _alarmSet = false;
    });
  }

  void _updateVolumeIncreaseRate(VolumeIncreaseRate volumeIncreaseRate) {
    print(volumeIncreaseRate);

    setState(() {
      _volumeIncreaseRate = volumeIncreaseRate;
      _alarmSet = false;
    });
  }

  void _updateVolume() async {
    final int steps = _alarmDuration * 12;
    final double timeDelta = 0.1 / _alarmDuration;

    double currentTime = 0.0;
    double volume = 0.0;

    for (int i = 0; i < steps; ++i) {
      await Future.delayed(const Duration(seconds: 5), () async {
        currentTime += timeDelta;
        volume = _determineVolume(currentTime);
        await _audioPlayer.setVolume(volume);
        print("Increasing volume to: $volume");
      });
    }

    print("Maximum volume reached!");
  }

  double _determineVolume(double x) {
    switch (_volumeIncreaseRate) {
      case VolumeIncreaseRate.Constant:
        return x;
      case VolumeIncreaseRate.Speeding:
        return pow(x, (10 / 6));
      case VolumeIncreaseRate.Slowing:
        return pow(x, (6 / 10));
      default:
        return x;
    }
  }

  void _alarm() async {
    /// Start player
    const streamLink = "http://kepler.shoutca.st:8404/";

    try {
      await _audioPlayer.open(Audio.liveStream(streamLink));
    } catch (e) {
      /// Use song as a backup
      await _audioPlayer.open(Audio("assets/audio/test.mp3"));
      print("Stream not working.");
    }

    await _audioPlayer.setVolume(0.0);

    _updateVolume();
  }
}
