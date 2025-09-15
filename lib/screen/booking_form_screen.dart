import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/room.dart';
import '../services/room_service.dart';
import '../services/booking_service.dart';
import '../models/auth_service.dart';

class BookingFormScreen extends StatefulWidget {
  final Room room;
  const BookingFormScreen({super.key, required this.room});

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _purposeController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final now = TimeOfDay.now();
    _startTime = now;

    int endHour = now.hour + 1;
    if (endHour >= 24) {
      endHour = 23;
    }
    _endTime = now.replacing(hour: endHour);
  }

  @override
  void dispose() {
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selectedDate != null) {
      setState(() {
        _selectedDate = selectedDate;
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final initialTime = isStartTime ? _startTime : _endTime;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (pickedTime != null) {
      setState(() {
        if (isStartTime) {
          _startTime = pickedTime;
          final startTimeInMinutes = _startTime.hour * 60 + _startTime.minute;
          final endTimeInMinutes = _endTime.hour * 60 + _endTime.minute;

          if (startTimeInMinutes >= endTimeInMinutes) {
            int newEndHour = _startTime.hour + 1;
            int newEndMinute = _startTime.minute;

            if (newEndHour >= 24) {
              newEndHour = 23;
              newEndMinute = 59;
            }

            if (newEndHour * 60 + newEndMinute <= startTimeInMinutes) {
              newEndHour = 23;
              newEndMinute = 59;
            }
            _endTime = TimeOfDay(hour: newEndHour, minute: newEndMinute);
          }
        } else {
          _endTime = pickedTime;
        }
      });
    }
  }

  DateTime get _startDateTime => DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute);
  DateTime get _endDateTime => DateTime(_selectedDate.year, _selectedDate.month,
      _selectedDate.day, _endTime.hour, _endTime.minute);

  String? _validateTimes() {
    if (_endDateTime.isBefore(_startDateTime) ||
        _endDateTime.isAtSameMomentAs(_startDateTime)) {
      return 'เวลาสิ้นสุดต้องมาหลังเวลาเริ่มต้น';
    }
    final duration = _endDateTime.difference(_startDateTime);
    if (duration.inMinutes < 30) return 'ระยะเวลาการจองต้องไม่น้อยกว่า 30 นาที';
    if (duration.inHours > 8) return 'ระยะเวลาการจองต้องไม่เกิน 8 ชั่วโมง';
    return null;
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    final timeValidation = _validateTimes();
    if (timeValidation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(timeValidation), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final bookingService =
          Provider.of<BookingService>(context, listen: false);
      final roomService = Provider.of<RoomService>(context, listen: false);

      final isRoomAvailable = await roomService.checkRoomAvailability(
          widget.room.id, _startDateTime, _endDateTime);
      if (!isRoomAvailable) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('ห้องไม่ว่างในช่วงเวลาที่เลือก'),
              backgroundColor: Colors.red));
        setState(() => _isLoading = false);
        return;
      }

      final success = await bookingService.createBooking(
        roomId: widget.room.id,
        userId: authService.currentUser!.id,
        startTime: _startDateTime,
        endTime: _endDateTime,
        purpose: _purposeController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'จองห้องเรียนสำเร็จ' : 'ไม่สามารถจองห้องได้'),
          backgroundColor: success ? Colors.green : Colors.red,
        ));
        if (success) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จองห้องเรียน'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRoomInfoCard(),
              const SizedBox(height: 24),
              _buildBookingFormCard(),
              const SizedBox(height: 24),
              _buildBookingSummaryCard(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ห้องที่เลือก',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(widget.room.name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(widget.room.location,
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.people, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text('ความจุ ${widget.room.capacity} คน',
                  style: TextStyle(color: Colors.grey.shade600)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingFormCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('รายละเอียดการจอง',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildPickerField(
                label: 'วันที่',
                onTap: _selectDate,
                icon: Icons.calendar_today,
                text: _formatDate(_selectedDate)),
            const SizedBox(height: 16),
            _buildPickerField(
                label: 'เวลาเริ่มต้น',
                onTap: () => _selectTime(context, true),
                icon: Icons.access_time,
                text: _startTime.format(context)),
            const SizedBox(height: 16),
            _buildPickerField(
                label: 'เวลาสิ้นสุด',
                onTap: () => _selectTime(context, false),
                icon: Icons.access_time,
                text: _endTime.format(context)),
            const SizedBox(height: 16),
            Text('วัตถุประสงค์การใช้งาน',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _purposeController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'ระบุวัตถุประสงค์การใช้งานห้อง...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty)
                  return 'กรุณาระบุวัตถุประสงค์';
                if (value.trim().length < 10)
                  return 'วัตถุประสงค์ต้องมีอย่างน้อย 10 ตัวอักษร';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerField(
      {required String label,
      required VoidCallback onTap,
      required IconData icon,
      required String text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(icon),
              const SizedBox(width: 12),
              Text(text, style: const TextStyle(fontSize: 16)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingSummaryCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('สรุปการจอง',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
            const SizedBox(height: 12),
            _buildSummaryRow('ห้อง', widget.room.name),
            _buildSummaryRow('วันที่', _formatDate(_selectedDate)),
            _buildSummaryRow('เวลา',
                '${_startTime.format(context)} - ${_endTime.format(context)}'),
            _buildSummaryRow('ระยะเวลา',
                _formatDuration(_endDateTime.difference(_startDateTime))),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitBooking,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
            : const Text('ยืนยันการจอง',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        SizedBox(
            width: 80,
            child: Text('$label:',
                style: TextStyle(
                    fontWeight: FontWeight.w500, color: Colors.blue.shade700))),
        Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.bold))),
      ]),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year + 543}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0 && minutes > 0) return '$hours ชั่วโมง $minutes นาที';
    if (hours > 0) return '$hours ชั่วโมง';
    return '$minutes นาที';
  }
}
