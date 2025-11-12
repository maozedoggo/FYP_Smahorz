// household_voting.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Modern dark-mode voting manager for choosing a household admin.
/// Uses RadioGroup to avoid deprecated APIs.
/// Copy this file into your project and use `HouseholdVotingManager()` in SettingsPage.
class HouseholdVotingManager extends StatefulWidget {
  const HouseholdVotingManager({super.key});

  @override
  State<HouseholdVotingManager> createState() => _HouseholdVotingManagerState();
}

class _HouseholdVotingManagerState extends State<HouseholdVotingManager> {
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _loading = true;
  String? _currentEmail;
  String? _householdId;
  DocumentReference<Map<String, dynamic>>? _householdRef;
  List<String> _members = [];
  String? _adminId;
  Map<String, String> _votes = {}; // voterEmail -> candidateEmail
  String? _selectedCandidateEmail; // chosen candidate for current user
  bool _submitting = false;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  @override
  void initState() {
    super.initState();
    _initAndListen();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _initAndListen() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    _currentEmail = user.email;
    if (_currentEmail == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    final userDoc = await _fire.collection('users').doc(_currentEmail).get();
    final data = userDoc.data();
    final hid = data != null ? (data['householdId'] as String?) : null;

    if (hid == null || hid.isEmpty) {
      if (!mounted) return;
      setState(() {
        _householdId = null;
        _householdRef = null;
        _members = [];
        _adminId = null;
        _votes = {};
        _loading = false;
      });
      return;
    }

    _householdId = hid;
    _householdRef = _fire.collection('households').doc(_householdId);

    _subscription = _householdRef!.snapshots().listen(
      (snap) {
        final d = snap.data();
        if (d == null) {
          if (!mounted) return;
          setState(() {
            _members = [];
            _adminId = null;
            _votes = {};
            _loading = false;
          });
          return;
        }

        final gotMembers = List<String>.from(d['members'] ?? <String>[]);
        final gotAdmin = d['adminId'] as String?;
        final rawVotes = Map<String, dynamic>.from(d['votes'] ?? {});
        final Map<String, String> normalizedVotes = {};
        rawVotes.forEach((k, v) {
          if (v is String) normalizedVotes[k] = v;
        });

        if (!mounted) return;
        setState(() {
          _members = gotMembers;
          _adminId = gotAdmin;
          _votes = normalizedVotes;
          _selectedCandidateEmail = _votes[_currentEmail];
          _loading = false;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => _loading = false);
      },
    );
  }

  bool get _isMember =>
      _householdId != null && _members.contains(_currentEmail);
  bool get _isAdminUser => _adminId != null && _adminId == _currentEmail;

  Future<void> _submitVote() async {
    if (!_isMember ||
        _selectedCandidateEmail == null ||
        _currentEmail == null ||
        _householdRef == null)
      return;

    if (!mounted) return;
    setState(() => _submitting = true);

    try {
      await _householdRef!.set({
        'votes': {_currentEmail!: _selectedCandidateEmail},
      }, SetOptions(merge: true));

      await _maybePromoteIfMajority();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Vote submitted.")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error voting: $e")));
      }
    }

    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _maybePromoteIfMajority() async {
    if (_householdRef == null) return;

    final snap = await _householdRef!.get();
    final data = snap.data();
    if (data == null) return;

    final members = List<String>.from(data['members'] ?? []);
    final votesRaw = Map<String, dynamic>.from(data['votes'] ?? {});
    final Map<String, int> counts = {};
    for (final v in votesRaw.values) {
      if (v is String) counts[v] = (counts[v] ?? 0) + 1;
    }
    if (members.isEmpty) return;
    final majority = (members.length / 2).floor() + 1;

    String? topUid;
    int topCount = 0;
    counts.forEach((candidateUid, cnt) {
      if (cnt > topCount) {
        topCount = cnt;
        topUid = candidateUid;
      }
    });

    if (topUid != null && topCount >= majority) {
      await _fire.runTransaction((tx) async {
        final hSnap = await tx.get(_householdRef!);
        final hData = hSnap.data();
        if (hData == null) return;

        final currentMembers = List<String>.from(hData['members'] ?? []);
        if (!currentMembers.contains(topUid)) return;

        final previousAdmin = hData['adminId'] as String?;
        tx.update(_householdRef!, {
          'adminId': topUid,
          'votes': <String, dynamic>{},
        });

        if (previousAdmin != null && previousAdmin.isNotEmpty) {
          tx.update(_fire.collection('users').doc(previousAdmin), {
            'role': 'member',
          });
        }
        tx.update(_fire.collection('users').doc(topUid), {'role': 'admin'});
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("New admin promoted by majority vote.")),
      );
    }
  }

  Future<void> _finalizeVotes() async {
    if (!mounted) return;
    setState(() => _submitting = true);

    try {
      await _maybePromoteIfMajority();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error finalizing: $e")));
      }
    }

    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _clearVotes() async {
    if (_householdRef == null) return;
    if (!mounted) return;
    setState(() => _submitting = true);

    try {
      await _householdRef!.update({'votes': {}});
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Votes cleared.")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error clearing votes: $e")));
      }
    }

    if (mounted) setState(() => _submitting = false);
  }

  Map<String, int> _computeCounts() {
    final Map<String, int> counts = {};
    for (var c in _votes.values) {
      counts[c] = (counts[c] ?? 0) + 1;
    }
    return counts;
  }

  // Local card helper to match SettingsPage card styling
  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade800),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeText = const TextStyle(color: Colors.white);

    if (_loading) {
      return _card(child: const Center(child: CircularProgressIndicator()));
    }

    if (!_isMember) {
      return _card(
        child: Column(
          children: [
            Text(
              "Household Voting",
              style: themeText.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "You are not in a household. Create or join a household to use voting.",
              style: themeText,
            ),
          ],
        ),
      );
    }

    final counts = _computeCounts();
    final majority = (_members.length / 2).floor() + 1;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Admin Election",
            style: themeText.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Current admin: ${_adminId == null ? '—' : (_adminId == _currentEmail ? 'You' : _adminId)}",
            style: themeText.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Text(
            "Cast your vote",
            style: themeText.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          // Modern RadioGroup implementation
          Column(
            children: _members.map((uid) {
              final count = counts[uid] ?? 0;
              return RadioListTile<String>(
                title: Text(uid, style: themeText),
                subtitle: uid == _adminId
                    ? const Text("Admin", style: TextStyle(color: Colors.blue))
                    : null,
                value: uid,
                groupValue: _selectedCandidateEmail,
                onChanged: _submitting
                    ? null
                    : (val) {
                        if (!mounted) return;
                        setState(() {
                          _selectedCandidateEmail = val;
                        });
                      },
                activeColor: Colors.blue,
                secondary: Text(
                  "$count votes",
                  style: themeText.copyWith(fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting || _selectedCandidateEmail == null
                      ? null
                      : _submitVote,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Vote / Change Vote"),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _maybePromoteIfMajority,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade800,
                ),
                child: const Text("Tally"),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(
            "Majority needed: $majority vote(s)",
            style: themeText.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),

          if (_isAdminUser) ...[
            const Divider(color: Colors.grey),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text("Finalize (promote if majority)"),
                    onPressed: _submitting ? null : _finalizeVotes,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.clear),
                    label: const Text("Clear Votes"),
                    onPressed: _submitting ? null : _clearVotes,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
