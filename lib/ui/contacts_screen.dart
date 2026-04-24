import 'package:flutter/material.dart';
import '../services/contact_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final ContactService _contactService = ContactService();
  List<Map<String, String>> _savedContacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final contacts = await _contactService.getEmergencyContacts();
    setState(() {
      _savedContacts = contacts;
    });
  }

  Future<void> _pickContact() async {
    if (await FlutterContacts.requestPermission(readonly: true)) {
      final contact = await FlutterContacts.openExternalPick();
      if (contact != null) {
        final fullContact = await FlutterContacts.getContact(contact.id);
        if (fullContact != null && fullContact.phones.isNotEmpty) {
          final String phone = fullContact.phones.first.number;
          final String name = fullContact.displayName;

          // Avoid duplicates
          if (!_savedContacts.any((c) => c['phone'] == phone)) {
            setState(() {
              _savedContacts.add({'name': name, 'phone': phone});
            });
            await _contactService.saveEmergencyContacts(_savedContacts);
          }
        } else {
           if(mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Selected contact has no phone number.')),
             );
           }
        }
      }
    }
  }

  Future<void> _removeContact(int index) async {
    setState(() {
      _savedContacts.removeAt(index);
    });
    await _contactService.saveEmergencyContacts(_savedContacts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3), // Microsoft-like light gray
      appBar: AppBar(
        title: const Text('Emergency Contacts', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Add close friends or family members to your emergency list. They will receive SMS alerts with your location when you trigger an SOS.",
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _savedContacts.length,
              itemBuilder: (context, index) {
                final contact = _savedContacts[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE5E5E5),
                      child: Icon(Icons.person, color: Colors.black54),
                    ),
                    title: Text(contact['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(contact['phone'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _removeContact(index),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pickContact,
                icon: const Icon(Icons.add),
                label: const Text("Add Contact"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0078D4), // Microsoft Blue
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
