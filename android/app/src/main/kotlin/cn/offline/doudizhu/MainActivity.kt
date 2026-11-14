package cn.offline.doudizhu
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
class MainActivity: FlutterActivity(){
 private var audio:GameAudio?=null
 private var transport:BluetoothTransport?=null
 override fun configureFlutterEngine(flutterEngine:FlutterEngine){super.configureFlutterEngine(flutterEngine);transport=BluetoothTransport(this,flutterEngine.dartExecutor.binaryMessenger);audio=GameAudio(this,flutterEngine.dartExecutor.binaryMessenger)}
 override fun onPause(){audio?.suspendAudio();super.onPause()}
 override fun onResume(){super.onResume();audio?.resumeAudio()}
 override fun onDestroy(){audio?.dispose();super.onDestroy()}
 override fun onRequestPermissionsResult(requestCode:Int,permissions:Array<out String>,grantResults:IntArray){super.onRequestPermissionsResult(requestCode,permissions,grantResults);transport?.permissions(requestCode,grantResults)}
}
