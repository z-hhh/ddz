package cn.offline.doudizhu

import android.Manifest
import android.app.Activity
import android.bluetooth.*
import android.content.*
import android.content.pm.PackageManager
import android.os.*
import io.flutter.plugin.common.*
import org.json.JSONObject
import java.io.DataInputStream
import java.io.DataOutputStream
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/** 仅经典蓝牙 RFCOMM。每条消息为 4 字节大端长度 + UTF-8 JSON，最大 256 KiB。 */
class BluetoothTransport(private val activity: Activity, messenger: BinaryMessenger): MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val adapter = (activity.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter
    private val uuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private val main = Handler(Looper.getMainLooper())
    private val pool = Executors.newCachedThreadPool()
    private val sockets = ConcurrentHashMap<String,BluetoothSocket>()
    private val pending = ConcurrentHashMap<String,BluetoothSocket>()
    private var server: BluetoothServerSocket? = null
    private var sink: EventChannel.EventSink? = null
    private var generation=0
    private var permissionResult: MethodChannel.Result?=null
    private var permissionAction: (() -> Unit)?=null
    private var registered=false
    init {MethodChannel(messenger,"cn.offline.doudizhu/transport").setMethodCallHandler(this);EventChannel(messenger,"cn.offline.doudizhu/events").setStreamHandler(this)}
    override fun onListen(args: Any?, events: EventChannel.EventSink){sink=events}
    override fun onCancel(args: Any?){sink=null}
    private fun emit(vararg values: Pair<String,Any?>){main.post {sink?.success(mapOf(*values))}}
    private fun error(message:String){emit("type" to "error","message" to message)}
    private fun allowed(result: MethodChannel.Result, action:()->Unit){
        val permissions=if(Build.VERSION.SDK_INT>=31) arrayOf(Manifest.permission.BLUETOOTH_CONNECT,Manifest.permission.BLUETOOTH_SCAN,Manifest.permission.BLUETOOTH_ADVERTISE) else arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        val missing=permissions.filter {activity.checkSelfPermission(it)!=PackageManager.PERMISSION_GRANTED}
        if(missing.isEmpty()){try{action()}catch(e:Exception){result.error("BLUETOOTH",e.message,null)}}else{
            if(permissionResult!=null){result.error("BUSY","请先完成权限授权",null);return}
            permissionResult=result;permissionAction=action;activity.requestPermissions(missing.toTypedArray(),810)
        }
    }
    fun permissions(request:Int,grants:IntArray){if(request!=810)return;val result=permissionResult;val action=permissionAction;permissionResult=null;permissionAction=null;if(grants.isNotEmpty()&&grants.all{it==PackageManager.PERMISSION_GRANTED}){try{action?.invoke()}catch(e:Exception){result?.error("BLUETOOTH",e.message,null)}}else{result?.error("PERMISSION","蓝牙权限被拒绝，请在系统设置中允许附近设备/位置权限",null)}}
    private fun ready(){check(adapter!=null){"此设备没有蓝牙"};check(adapter.isEnabled){"请先在系统设置中开启蓝牙"}}
    override fun onMethodCall(call:MethodCall,result:MethodChannel.Result){
        when(call.method){
            "createRoom" -> allowed(result){ready();cleanup();val epoch=generation
                server=adapter.listenUsingRfcommWithServiceRecord("斗地主",uuid)
                activity.startActivity(Intent(BluetoothAdapter.ACTION_REQUEST_DISCOVERABLE).putExtra(BluetoothAdapter.EXTRA_DISCOVERABLE_DURATION,300))
                pool.execute {try{while(epoch==generation){val socket=server?.accept()?:break;if(sockets.size>=2){socket.close()}else attach(socket,epoch)}}catch(e:Exception){if(epoch==generation)error("房间监听中断，请重新创建房间")}}
                result.success(null)
            }
            "discover" -> allowed(result){ready();register();adapter.bondedDevices.forEach{emit("type" to "found","id" to it.address,"name" to (it.name?:"已配对设备"))};adapter.cancelDiscovery();if(!adapter.startDiscovery())error("无法扫描，请开启位置服务后重试");main.postDelayed({try{adapter.cancelDiscovery();emit("type" to "scanDone")}catch(_:Exception){}},30000);result.success(null)}
            "join" -> allowed(result){ready();val id=call.argument<String>("id")!!;adapter.cancelDiscovery();val epoch=generation;val socket=adapter.getRemoteDevice(id).createRfcommSocketToServiceRecord(uuid);pending[id]=socket
                main.postDelayed({if(pending.remove(id,socket)){try{socket.close()}catch(_:Exception){};error("30 秒未连接，请靠近房主并重试")}},30000)
                pool.execute {try{socket.connect();pending.remove(id);if(epoch==generation)attach(socket,epoch)else socket.close()}catch(e:Exception){pending.remove(id);try{socket.close()}catch(_:Exception){};if(epoch==generation)error("连接失败，请确认房主正在等待、完成系统蓝牙配对后重试")}};result.success(null)
            }
            "send" -> {val peer=call.argument<String>("peer");val message=call.argument<Map<String,Any?>>("message")?:emptyMap();val data=JSONObject(message).toString().toByteArray(Charsets.UTF_8);if(data.isEmpty()||data.size>262144){result.error("FRAME","消息长度非法",null);return};val targets=if(peer==null)sockets.toMap() else sockets.filterKeys{it==peer};if(targets.isEmpty()){result.error("OFFLINE","连接已断开",null);return};pool.execute{targets.forEach{(id,socket)->try{synchronized(socket){val output=DataOutputStream(socket.outputStream);output.writeInt(data.size);output.write(data);output.flush()}}catch(_:Exception){left(id,socket)}}};result.success(null)}
            "dispose" -> {cleanup();result.success(null)}
            else -> result.notImplemented()
        }
    }
    private fun register(){if(registered)return;val filter=IntentFilter(BluetoothDevice.ACTION_FOUND);if(Build.VERSION.SDK_INT>=33)activity.registerReceiver(receiver,filter,Context.RECEIVER_EXPORTED)else activity.registerReceiver(receiver,filter);registered=true}
    private val receiver=object:BroadcastReceiver(){override fun onReceive(c:Context?,intent:Intent?){if(intent?.action==BluetoothDevice.ACTION_FOUND){@Suppress("DEPRECATION") val device=intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)?:return;try{emit("type" to "found","id" to device.address,"name" to (device.name?:"蓝牙设备"))}catch(_:SecurityException){error("蓝牙权限已撤销")}}}}
    private fun attach(socket:BluetoothSocket,epoch:Int){val id=socket.remoteDevice.address;sockets.put(id,socket)?.let{try{it.close()}catch(_:Exception){}};emit("type" to "connected","peer" to id)
        pool.execute{try{val input=DataInputStream(socket.inputStream);while(epoch==generation){val n=input.readInt();require(n in 1..262144);val bytes=ByteArray(n);input.readFully(bytes);val obj=JSONObject(String(bytes,Charsets.UTF_8));emit("type" to "message","peer" to id,"message" to jsonMap(obj))}}catch(_:Exception){}finally{left(id,socket)}}
    }
    private fun jsonValue(v:Any?):Any?=when(v){is JSONObject->jsonMap(v);is org.json.JSONArray->(0 until v.length()).map{jsonValue(v.get(it))};JSONObject.NULL->null;else->v}
    private fun jsonMap(obj:JSONObject):Map<String,Any?> = obj.keys().asSequence().associateWith{jsonValue(obj.get(it))}
    private fun left(id:String,socket:BluetoothSocket){if(sockets.remove(id,socket)){try{socket.close()}catch(_:Exception){};emit("type" to "left","peer" to id)}}
    private fun cleanup(){generation++;try{server?.close()}catch(_:Exception){};server=null;pending.values.forEach{try{it.close()}catch(_:Exception){}};pending.clear();sockets.toMap().forEach{(id,s)->left(id,s)};if(registered){try{activity.unregisterReceiver(receiver)}catch(_:Exception){};registered=false};try{adapter?.cancelDiscovery()}catch(_:Exception){}}
}
