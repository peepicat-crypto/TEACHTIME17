import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/booking.dart';
import '../models/room.dart';
import '../models/auth_service.dart';
import '../services/booking_service.dart';
import '../services/room_service.dart';

class EditBookingScreen extends StatefulWidget {
  final Booking booking;

  const EditBookingScreen({super.key, required this.booking});

  @override
  // ignore: library_private_types_in_public_api
  _EditBookingScreenState createState() => _EditBookingScreenState();
}

class _EditBookingScreenState extends State<EditBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _purposeController;
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _isLoading = false;
  Room? _currentRoom;

  @override
  void initState() {
    super.initState();
    _purposeController = TextEditingController(text: widget.booking.purpose);
    _selectedDate = widget.booking.startTime; // ใช้วันที่จาก startTime
    _startTime = TimeOfDay.fromDateTime(widget.booking.startTime);
    _endTime = TimeOfDay.fromDateTime(widget.booking.endTime);
    // ใช้ WidgetsBinding.instance.addPostFrameCallback เพื่อให้ context พร้อมใช้งาน
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRoomDetails();
    });
  }

  Future<void> _loadRoomDetails() async {
    // ไม่ต้อง setState loading ที่นี่ เพราะจะทำให้เกิดข้อผิดพลาดขณะ build
    try {
      final roomService = Provider.of<RoomService>(context, listen: false);
      // สมมติว่ามีฟังก์ชัน getRoomById ใน RoomService
      final room = await roomService.getRoomById(widget.booking.roomId);
      if (mounted) {
        setState(() {
          _currentRoom = room;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูลห้อง: $e')),
        );
      }
    }
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

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final timeValidation = _validateTimes();
    if (timeValidation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(timeValidation), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bookingService =
          Provider.of<BookingService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('เกิดข้อผิดพลาด: ไม่พบข้อมูลผู้ใช้')));
        setState(() => _isLoading = false);
        return;
      }

      final success = await bookingService.updateBooking(
        bookingId: widget.booking.id,
        userId: currentUser.id,
        userRole: currentUser.role,
        startTime: _startDateTime,
        endTime: _endDateTime,
        purpose: _purposeController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(success ? 'อัปเดตการจองสำเร็จ' : 'ไม่สามารถอัปเดตการจองได้'),
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

  String _formatDate(DateTime date) {
    const months = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year + 543}';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    return '$hours ชั่วโมง $minutes นาที';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แก้ไขการจอง'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_currentRoom == null)
                      const Center(child: CircularProgressIndicator())
                    else
                      _buildRoomInfoCard(),
                    const SizedBox(height: 24),
                    _buildEditFormCard(),
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
            Text('ห้องที่จอง',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_currentRoom!.name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_currentRoom!.location,
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.people, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text('ความจุ ${_currentRoom!.capacity} คน',
                  style: TextStyle(color: Colors.grey.shade600)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildEditFormCard() {
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
                text: _formatTime(_startTime)),
            const SizedBox(height: 16),
            _buildPickerField(
                label: 'เวลาสิ้นสุด',
                onTap: () => _selectTime(context, false),
                icon: Icons.access_time,
                text: _formatTime(_endTime)),
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
            _buildSummaryRow('ห้อง', _currentRoom?.name ?? 'กำลังโหลด...'),
            _buildSummaryRow('วันที่', _formatDate(_selectedDate)),
            _buildSummaryRow('เวลา',
                '${_formatTime(_startTime)} - ${_formatTime(_endTime)}'),
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
        onPressed: _isLoading ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('บันทึกการแก้ไข',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:',
                style: TextStyle(
                    fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
          ),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
