import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/mobile_api_service.dart';

class LeadershipAddScreen extends StatefulWidget {
  const LeadershipAddScreen({super.key, required this.role, this.barangays = const []});
  final String role;
  final List<Map<String, dynamic>> barangays;
  @override State<LeadershipAddScreen> createState() => _LeadershipAddScreenState();
}
class _LeadershipAddScreenState extends State<LeadershipAddScreen> {
  final first=TextEditingController(), last=TextEditingController(), email=TextEditingController(), phone=TextEditingController(), term=TextEditingController();
  String? barangay; bool saving=false;
  @override void initState(){super.initState(); if(widget.barangays.isNotEmpty) barangay='${widget.barangays.first['barangay_id']}';}
  @override void dispose(){first.dispose();last.dispose();email.dispose();phone.dispose();term.dispose();super.dispose();}
  Future<void> save() async {
    if(first.text.trim().isEmpty||last.text.trim().isEmpty||email.text.trim().isEmpty){_msg('Complete the required fields.');return;}
    final emailOk=RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text.trim());
    final p=phone.text.trim(); final phoneOk=p.isEmpty||RegExp(r'^09\d{9}$').hasMatch(p);
    if(!emailOk||!phoneOk){_msg('Enter a valid email and Philippine phone number (09XXXXXXXXX).');return;}
    setState(()=>saving=true);
    try { if(widget.role=='Chairman'){if(barangay==null)throw MobileApiException('Select a barangay.');await MobileApiService.createChairmanAccount(firstName:first.text.trim(),lastName:last.text.trim(),email:email.text.trim(),phone:p,barangayId:int.parse(barangay!));} else if(widget.role=='Secretary'){await MobileApiService.createSecretaryAccount(firstName:first.text.trim(),lastName:last.text.trim(),email:email.text.trim(),phone:p,term:term.text.trim());} else {await MobileApiService.createCouncilMember(name:'${first.text.trim()} ${last.text.trim()}',email:email.text.trim(),phone:p,term:term.text.trim());} if(mounted)Navigator.pop(context,true); } on MobileApiException catch(e){_msg(e.message);} finally{if(mounted)setState(()=>saving=false);}
  }
  void _msg(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text('Add SK ${widget.role}')),body:ListView(padding:const EdgeInsets.all(20),children:[Text('Add SK ${widget.role}',style:Theme.of(context).textTheme.headlineSmall),const SizedBox(height:20),if(widget.role=='Chairman')DropdownButtonFormField<String>(initialValue:barangay,decoration:const InputDecoration(labelText:'Barangay'),items:widget.barangays.map((b)=>DropdownMenuItem(value:'${b['barangay_id']}',child:Text('${b['barangay_name']}'))).toList(),onChanged:(v)=>setState(()=>barangay=v)),if(widget.role=='Chairman')const SizedBox(height:14),TextField(controller:first,decoration:const InputDecoration(labelText:'First name')),const SizedBox(height:14),TextField(controller:last,decoration:const InputDecoration(labelText:'Last name')),const SizedBox(height:14),TextField(controller:email,decoration:const InputDecoration(labelText:'Email')),const SizedBox(height:14),TextField(controller:phone,inputFormatters:[FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))],keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Phone (optional)')),if(widget.role!='Chairman')const SizedBox(height:14),if(widget.role!='Chairman')TextField(controller:term,decoration:const InputDecoration(labelText:'Term')),const SizedBox(height:28),FilledButton(onPressed:saving?null:save,child:Text(saving?'Saving...':'Create Account'))]));
}
