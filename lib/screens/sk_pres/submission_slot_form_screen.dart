import 'package:flutter/material.dart';
import '../../services/mobile_api_service.dart';

class SubmissionSlotFormScreen extends StatefulWidget {
  const SubmissionSlotFormScreen({super.key});
  @override State<SubmissionSlotFormScreen> createState() => _SubmissionSlotFormScreenState();
}
class _SubmissionSlotFormScreenState extends State<SubmissionSlotFormScreen> {
  final title = TextEditingController(), description = TextEditingController();
  DateTime start = DateTime.now(), end = DateTime.now().add(const Duration(days: 7));
  String type = 'accomplishment_report', role = 'Both'; bool saving = false;
  @override void dispose(){title.dispose();description.dispose();super.dispose();}
  Future<void> pick(bool first) async { final d=await showDatePicker(context: context, initialDate: first?start:end, firstDate: DateTime(2020), lastDate: DateTime(2100)); if(d==null)return; setState(()=>first?start=d:end=d); }
  Future<void> save() async { if(title.text.trim().isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter a submission title.')));return;} if(end.isBefore(start)){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('End date cannot be before start date.')));return;} setState(()=>saving=true); try{await MobileApiService.createSubmissionSlot(submissionType:type,title:title.text.trim(),description:description.text.trim(),role:role,startDate:start,endDate:end); if(mounted)Navigator.pop(context,true);}on MobileApiException catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.message)));}finally{if(mounted)setState(()=>saving=false);} }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Create Submission Slot')),body:ListView(padding:const EdgeInsets.all(20),children:[Text('Create submission slot',style:Theme.of(context).textTheme.headlineSmall),const SizedBox(height:20),TextField(controller:title,decoration:const InputDecoration(labelText:'Submission title')),const SizedBox(height:14),TextField(controller:description,maxLines:4,decoration:const InputDecoration(labelText:'Description')),const SizedBox(height:14),DropdownButtonFormField(initialValue:type,decoration:const InputDecoration(labelText:'Submission type'),items:const[DropdownMenuItem(value:'accomplishment_report',child:Text('Accomplishment Report')),DropdownMenuItem(value:'budget_report',child:Text('Budget Report'))],onChanged:(v)=>setState(()=>type=v??type)),const SizedBox(height:14),DropdownButtonFormField(initialValue:role,decoration:const InputDecoration(labelText:'Target role'),items:const[DropdownMenuItem(value:'SK Chairman',child:Text('SK Chairman')),DropdownMenuItem(value:'SK Secretary',child:Text('SK Secretary')),DropdownMenuItem(value:'Both',child:Text('Both'))],onChanged:(v)=>setState(()=>role=v??role)),const SizedBox(height:14),Row(children:[Expanded(child:OutlinedButton(onPressed:()=>pick(true),child:Text('Start: ${start.year}-${start.month}-${start.day}'))),const SizedBox(width:10),Expanded(child:OutlinedButton(onPressed:()=>pick(false),child:Text('End: ${end.year}-${end.month}-${end.day}')))]),const SizedBox(height:28),FilledButton(onPressed:saving?null:save,child:Text(saving?'Creating...':'Create Slot'))]));
}

