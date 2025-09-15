// ignore_for_file: sized_box_for_whitespace

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/room.dart';
import '../services/room_service.dart';
import '../services/booking_service.dart';
import '../models/auth_service.dart';

class BookingFormScreenDesktop extends StatefulWidget {
  final Room room;
  const BookingFormScreenDesktop({super.key, required this.room});

  @override
  State<BookingFormScreenDesktop> createState() =>
      _BookingFormScreenDesktopState();
}

class _BookingFormScreenDesktopState extends State<BookingFormScreenDesktop> {
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
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width > 1024;

    return Scaffold(
      appBar: AppBar(
        title: const Text('จองห้องเรียน'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SizedBox(
        height: screenSize.height,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 32 : 16),
          child: Center(
            child: Container(
              constraints:
                  BoxConstraints(maxWidth: isDesktop ? 1200 : double.infinity),
              child: Form(
                key: _formKey,
                child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: Column(children: [
            _buildRoomInfoCard(),
            const SizedBox(height: 24),
            _buildBookingSummaryCard(),
          ]),
        ),
        const SizedBox(width: 32),
        Expanded(
          flex: 1,
          child: Column(children: [
            _buildBookingFormCard(),
            const SizedBox(height: 24),
            _buildSubmitButton(),
          ]),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildRoomInfoCard(),
        const SizedBox(height: 24),
        _buildBookingFormCard(),
        const SizedBox(height: 24),
        _buildBookingSummaryCard(),
        const SizedBox(height: 32),
        _buildSubmitButton(),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildRoomInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.meeting_room, color: Colors.blue.shade600, size: 28),
              const SizedBox(width: 12),
              Text('ห้องที่เลือก',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800)),
            ]),
            const SizedBox(height: 16),
            Text(widget.room.name,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.location_on, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(widget.room.location,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.people, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text('ความจุ ${widget.room.capacity} คน',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.category, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(_getRoomTypeText(widget.room.type),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingFormCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.edit_calendar, color: Colors.blue.shade600, size: 28),
              const SizedBox(width: 12),
              Text('รายละเอียดการจอง',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800)),
            ]),
            const SizedBox(height: 24),
            _buildFormField(
              label: 'วันที่',
              icon: Icons.calendar_today,
              child: InkWell(
                onTap: _selectDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade50),
                  child: Text(_formatDate(_selectedDate),
                      style: const TextStyle(fontSize: 16)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            MediaQuery.of(context).size.width > 600
                ? Row(children: [
                    Expanded(
                        child: _buildTimeField(
                            label: 'เวลาเริ่มต้น',
                            time: _startTime,
                            onTap: () => _selectTime(context, true))),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildTimeField(
                            label: 'เวลาสิ้นสุด',
                            time: _endTime,
                            onTap: () => _selectTime(context, false))),
                  ])
                : Column(children: [
                    _buildTimeField(
                        label: 'เวลาเริ่มต้น',
                        time: _startTime,
                        onTap: () => _selectTime(context, true)),
                    const SizedBox(height: 20),
                    _buildTimeField(
                        label: 'เวลาสิ้นสุด',
                        time: _endTime,
                        onTap: () => _selectTime(context, false)),
                  ]),
            const SizedBox(height: 20),
            _buildFormField(
              label: 'วัตถุประสงค์การใช้งาน',
              icon: Icons.description,
              child: TextFormField(
                controller: _purposeController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'ระบุวัตถุประสงค์การใช้งานห้อง...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.all(16),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return 'กรุณาระบุวัตถุประสงค์';
                  if (value.trim().length < 10)
                    return 'วัตถุประสงค์ต้องมีอย่างน้อย 10 ตัวอักษร';
                  return null;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingSummaryCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.blue.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.summarize, color: Colors.blue.shade700, size: 28),
              const SizedBox(width: 12),
              Text('สรุปการจอง',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800)),
            ]),
            const SizedBox(height: 16),
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
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _submitBooking,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
            : const Icon(Icons.book_online, size: 24),
        label: Text(_isLoading ? 'กำลังจอง...' : 'ยืนยันการจอง',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
      ),
    );
  }

  Widget _buildFormField(
      {required String label, required IconData icon, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 20, color: Colors.blue.shade600),
          const SizedBox(width: 8),
          Text(label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
        ]),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildTimeField(
      {required String label,
      required TimeOfDay time,
      required VoidCallback onTap}) {
    return _buildFormField(
      label: label,
      icon: Icons.access_time,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade50),
          child:
              Text(time.format(context), style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                    fontSize: 16)),
          ),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 16))),
        ],
      ),
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

  // --- ส่วนที่แก้ไข: เพิ่มฟังก์ชันที่ขาดไป ---
  String _getRoomTypeText(String type) {
    switch (type) {
      case 'classroom':
        return 'ห้องเรียน';
      case 'computerLab':
        return 'ห้องปฏิบัติการคอมพิวเตอร์';
      case 'meetingRoom':
        return 'ห้องประชุม';
      case 'lectureHall':
        return 'หอประชุม';
      case 'sciencelab':
        return 'ห้องปฏิบัติการวิทยาศาสตร์';
      default:
        return type;
    }
  }
}
