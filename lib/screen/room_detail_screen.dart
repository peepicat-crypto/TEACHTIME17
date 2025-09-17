// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/room.dart';
import '../services/booking_service.dart';
import '../models/booking.dart';
import '../models/room_booking_table.dart';
import '../models/room_image_widget.dart';
import 'booking_form_screen_desktop.dart';

class RoomDetailScreenResponsive extends StatefulWidget {
  final Room room;

  const RoomDetailScreenResponsive({
    super.key,
    required this.room,
  });

  @override
  State<RoomDetailScreenResponsive> createState() =>
      _RoomDetailScreenResponsiveState();
}

class _RoomDetailScreenResponsiveState
    extends State<RoomDetailScreenResponsive> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 768;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.room.name,
          style: const TextStyle(fontSize: 18),
        ),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 1200 : double.infinity,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMainContent(isDesktop, isMobile),
                      const SizedBox(height: 24),
                      _buildBookingSection(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMainContent(bool isDesktop, bool isMobile) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildInfoSection(),
                const SizedBox(height: 16),
                _buildAmenitiesSection(),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 3,
            child: _buildImageAndBookingSection(isCompact: false),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          _buildImageAndBookingSection(isCompact: isMobile),
          const SizedBox(height: 24),
          _buildInfoSection(),
          const SizedBox(height: 16),
          _buildAmenitiesSection(),
        ],
      );
    }
  }

  Widget _buildInfoSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ข้อมูลพื้นฐาน',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('ชื่อห้อง', widget.room.name),
            _buildInfoRow('ตำแหน่ง', widget.room.location),
            _buildInfoRow('ความจุ', '${widget.room.capacity} คน'),
            _buildInfoRow('ประเภท', _getRoomTypeText(widget.room.type)),
            _buildInfoRow(
              'สถานะ',
              widget.room.isAvailable ? 'ว่าง' : 'ไม่ว่าง',
              valueColor:
                  _isRoomCurrentlyOccupied() ? Colors.red : Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmenitiesSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'สิ่งอำนวยความสะดวก',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            if (widget.room.amenities.isEmpty)
              const Text(
                'ไม่มีข้อมูลสิ่งอำนวยความสะดวก',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.room.amenities
                    .map((amenity) => _buildAmenityChip(amenity))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageAndBookingSection({required bool isCompact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 4,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            height: isCompact ? 200 : 300,
            decoration: BoxDecoration(
              color: Colors.grey[200],
            ),
            child: RoomImageWidget(
              roomId: widget.room.id,
              roomName: widget.room.name,
              fit: BoxFit.cover,
              enableFullScreen: true,
              showExpandIcon: true,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: isCompact
                ? Column(
                    children: [
                      _buildStatusRow(),
                      const SizedBox(height: 12),
                      _buildBookingButton(),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatusRow(),
                      _buildBookingButton(),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.event_available,
          size: 28,
          color: _isRoomCurrentlyOccupied() ? Colors.red : Colors.green,
        ),
        const SizedBox(width: 8),
        Text(
          _isRoomCurrentlyOccupied() ? 'ไม่ว่าง' : 'ว่าง',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _isRoomCurrentlyOccupied() ? Colors.red : Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildBookingButton() {
    return ElevatedButton.icon(
      onPressed: !_isRoomCurrentlyOccupied()
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookingFormScreenDesktop(
                    room: widget.room,
                  ),
                ),
              );
            }
          : null,
      icon: const Icon(Icons.book_online, size: 18),
      label: const Text('จองห้อง'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  Widget _buildBookingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ตารางการจอง',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: RoomBookingTable(roomId: widget.room.id),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmenityChip(String amenity) {
    return Chip(
      label: Text(
        amenity,
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: Colors.blue.shade50,
      side: BorderSide(color: Colors.blue.shade200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

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

  /// --- ใช้ _isRoomCurrentlyOccupied() ภายใน class ---
  bool _isRoomCurrentlyOccupied() {
    final now = DateTime.now();
    final bookingService = Provider.of<BookingService>(context, listen: false);
    final roomBookings = bookingService.bookings.where(
      (booking) =>
          booking.roomId == widget.room.id &&
          booking.status == BookingStatus.confirmed.name &&
          now.isAfter(booking.startTime) &&
          now.isBefore(booking.endTime),
    );
    return roomBookings.isNotEmpty;
  }
}
