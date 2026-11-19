import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend.dart';
import 'csv_export.dart';
import 'ids.dart';
import 'models.dart';
import '../l10n/l10n.dart';
import '../log.dart';

/// Real backend. Rights are enforced by the database (row level security)
/// and every decision is taken by an SQL function: see supabase/migrations.
class SupabaseBackend extends RemboBackend {
  SupabaseBackend(this._client, {this.receiptReader = false});
  final SupabaseClient _client;

  /// True once the `read-receipt` Edge Function is deployed.
  final bool receiptReader;

  static const _bucket = 'receipts';
  static const _expenseColumns = '*, profiles(full_name), status_events(*)';

  AppUser? _user;

  @override
  bool get isDemo => false;

  /// Runs a request and turns every failure into a [RemboException] with
  /// a message the person can read.
  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request().timeout(const Duration(seconds: 30));
    } on RemboException {
      rethrow;
    } on AuthRetryableFetchException {
      throw _offline;
    } on AuthException catch (e) {
      throw RemboException(_authMessage(e));
    } on PostgrestException catch (e) {
      // P0001: a business rule refused by one of our SQL functions, whose
      // message is written for the user.
      if (e.code == 'P0001') throw RemboException(e.message);
      if (e.code == '42501' || e.code == 'PGRST301') {
        throw RemboException(tr('Vous n’avez pas accès à cette action.'));
      }
      throw RemboException(
        tr('Le serveur a refusé la demande. Réessayez dans un instant.'),
      );
    } on StorageException {
      throw RemboException(
        tr('Le justificatif n’a pas pu être enregistré.'),
        network: true,
      );
    } on TimeoutException {
      throw _offline;
    } on SocketException {
      throw _offline;
    } on HttpException {
      throw _offline;
    } catch (e) {
      // http.ClientException and similar transport failures.
      if ('$e'.contains('ClientException') ||
          '$e'.contains('SocketException')) {
        throw _offline;
      }
      throw RemboException(tr('Une erreur inattendue est survenue.'));
    }
  }

  static RemboException get _offline => RemboException(
    tr('Connexion impossible. Vérifiez votre réseau puis réessayez.'),
    network: true,
  );

  static String _authMessage(AuthException e) => switch (e.code) {
    'invalid_credentials' => tr('E-mail ou mot de passe incorrect.'),
    'email_not_confirmed' => tr(
      'Confirmez d’abord votre adresse avec le lien reçu par e-mail.',
    ),
    'user_already_exists' ||
    'email_exists' => tr('Un compte existe déjà pour cet e-mail.'),
    'weak_password' => tr('Mot de passe trop faible.'),
    'over_request_rate_limit' || 'over_email_send_rate_limit' => tr(
      'Trop de tentatives. Réessayez plus tard.',
    ),
    'signup_disabled' => tr('La création de compte est désactivée.'),
    _ => tr('Authentification impossible. Réessayez.'),
  };

  String get _uid =>
      _client.auth.currentUser?.id ??
      (throw RemboException(tr('Session expirée. Reconnectez-vous.')));

  String get _companyId =>
      _user?.companyId ??
      (throw RemboException(tr('Aucune entreprise associée à ce compte.')));

  Future<AppUser?> _loadUser() async {
    final auth = _client.auth.currentUser;
    if (auth == null) return _user = null;
    // An invitation is joined only on the person's answer (acceptInvitation).
    final m = await _client
        .from('memberships')
        .select('role, company_id, companies(name)')
        .eq('profile_id', auth.id)
        .maybeSingle();
    final link = await _client
        .from('whatsapp_links')
        .select('phone')
        .eq('profile_id', auth.id)
        .maybeSingle();
    final name = (auth.userMetadata?['full_name'] as String?)?.trim();
    return _user = AppUser(
      id: auth.id,
      email: auth.email ?? '',
      fullName: name == null || name.isEmpty ? (auth.email ?? '') : name,
      role: UserRole.parse(m?['role'] as String?),
      companyId: m?['company_id'] as String?,
      companyName: ((m?['companies'] as Map?)?['name'] as String?) ?? '',
      whatsappPhone: link?['phone'] as String?,
    );
  }

  // Session ---------------------------------------------------------------
  @override
  Future<AppUser?> restoreSession() => _guard(_loadUser);

  @override
  Future<AppUser> signIn(String email, String password) => _guard(() async {
    await _client.auth.signInWithPassword(email: email, password: password);
    return (await _loadUser())!;
  });

  @override
  Future<AppUser?> signUp({
    required String email,
    required String password,
    required String fullName,
  }) => _guard(() async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
    if (response.session == null) return null;
    return _loadUser();
  });

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _client.auth.resetPasswordForEmail(email));

  @override
  Future<void> signOut() async {
    _user = null;
    try {
      await _client.auth.signOut();
    } catch (e, st) {
      logFailure('sign out on the server', e, st);
      // The local session is cleared even when the server is unreachable.
    }
  }

  @override
  Future<AppUser> createCompany({
    required String name,
    String ice = '',
    String city = '',
  }) => _guard(() async {
    await _client.rpc<dynamic>(
      'create_company',
      params: {'p_name': name.trim(), 'p_ice': ice, 'p_city': city},
    );
    return (await _loadUser())!;
  });

  @override
  Future<CompanyInvitation?> pendingInvitation() => _guard(() async {
    final rows = await _client.rpc<dynamic>('my_invitation') as List? ?? [];
    if (rows.isEmpty) return null;
    final row = Map<String, dynamic>.from(rows.first as Map);
    return CompanyInvitation(
      companyName: row['company_name'] as String,
      role: UserRole.parse(row['role'] as String?),
    );
  });

  @override
  Future<AppUser> acceptInvitation() => _guard(() async {
    final joined = await _client.rpc<dynamic>('accept_invitation');
    if (joined != true) {
      throw RemboException(tr('Cette invitation n’est plus valable.'));
    }
    return (await _loadUser())!;
  });

  // Expenses --------------------------------------------------------------
  @override
  Future<List<Expense>> fetchExpenses() => _guard(() async {
    final rows = await _client
        .from('expenses')
        .select(_expenseColumns)
        .order('created_at', ascending: false)
        .limit(500);
    return [for (final r in rows) Expense.fromJson(r)];
  });

  Future<Expense> _one(String id) async => Expense.fromJson(
    await _client
        .from('expenses')
        .select(_expenseColumns)
        .eq('id', id)
        .single(),
  );

  @override
  Future<Expense> saveDraft(
    Expense draft, {
    Uint8List? receiptBytes,
    String? receiptName,
    String? createId,
  }) => _guard(() async {
    final values = draft.toWritableJson();
    var id = draft.id;
    if (id.isEmpty) {
      id = createId ?? newUuid();
      try {
        await _client.from('expenses').insert({
          'id': id,
          'company_id': _companyId,
          'employee_id': _uid,
          ...values,
        });
      } on PostgrestException catch (e) {
        // 23505: this id already exists, the first attempt reached the
        // server. Carry on as an update.
        if (e.code != '23505') rethrow;
        await _updateEditable(id, values);
      }
    } else {
      await _updateEditable(id, values);
    }
    if (receiptBytes != null) {
      final ext = (receiptName ?? '').toLowerCase().split('.').last;
      final type = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        _ => 'image/jpeg',
      };
      // One object per expense, in the owner's folder (see storage rules).
      final path = '$_uid/$id';
      try {
        await _client.storage
            .from(_bucket)
            .uploadBinary(
              path,
              receiptBytes,
              fileOptions: FileOptions(upsert: true, contentType: type),
            );
      } on StorageException catch (e) {
        // The storage rules lock the receipt of a submitted expense.
        if (isLockedReceipt(e)) {
          throw RemboException(
            tr('Ce justificatif est verrouillé : la dépense a été soumise.'),
          );
        }
        rethrow;
      }
      await _updateEditable(id, {'receipt_path': path});
    }
    return _one(id);
  });

  /// Writes [values] on an expense its owner may still edit. Row level
  /// security skips any other row without an error: an empty answer means
  /// nothing was written.
  Future<void> _updateEditable(String id, Map<String, dynamic> values) async {
    final rows = await _client
        .from('expenses')
        .update(values)
        .eq('id', id)
        .select('id');
    if (rows.isEmpty) {
      throw RemboException(tr('Cette dépense ne peut plus être modifiée.'));
    }
  }

  @override
  Future<void> deleteDraft(String id) => _guard(() async {
    final e = await _one(id);
    await _client.from('expenses').delete().eq('id', id);
    if (e.hasReceipt) {
      try {
        await _client.storage.from(_bucket).remove([e.receiptPath!]);
      } catch (e, st) {
        logFailure('orphan receipt not removed', e, st);
        // An orphan picture is harmless; the row is gone.
      }
    }
  });

  @override
  Future<Expense> submit(String id) => _guard(() async {
    await _client.rpc<dynamic>('submit_expense', params: {'p_id': id});
    return _one(id);
  });

  @override
  Future<Expense> decide(String id, {required bool approve, String? reason}) =>
      _guard(() async {
        await _client.rpc<dynamic>(
          'decide_expense',
          params: {'p_id': id, 'p_approve': approve, 'p_reason': reason ?? ''},
        );
        return _one(id);
      });

  @override
  Future<int> approveCompliant(List<String> ids) => _guard(() async {
    final n = await _client.rpc<dynamic>(
      'approve_compliant',
      params: {'p_ids': ids},
    );
    return (n as num?)?.toInt() ?? 0;
  });

  /// Contract of the optional `read-receipt` Edge Function:
  /// request  `{ "file_name": "...", "image_base64": "..." }`
  /// response `{ "unreadable": bool, "supplier": str?, "supplier_ice": str?,
  ///             "date": "YYYY-MM-DD"?, "amount_cents": int?,
  ///             "vat_cents": int? }`
  @override
  Future<ReceiptReading?> readReceipt(Uint8List bytes, String name) async {
    if (!receiptReader) return null;
    try {
      final response = await _client.functions
          .invoke(
            'read-receipt',
            body: {'file_name': name, 'image_base64': base64Encode(bytes)},
          )
          .timeout(const Duration(seconds: 30));
      final data = response.data;
      if (data is! Map) return null;
      return ReceiptReading(
        unreadable: data['unreadable'] == true,
        supplier: data['supplier'] as String?,
        supplierIce: data['supplier_ice'] as String?,
        date: data['date'] is String
            ? DateTime.tryParse(data['date'] as String)
            : null,
        amountCents: (data['amount_cents'] as num?)?.toInt(),
        vatCents: (data['vat_cents'] as num?)?.toInt(),
      );
    } catch (e, st) {
      logFailure('receipt reading', e, st);
      return null; // No reading: the person types the values.
    }
  }

  @override
  Future<String?> receiptUrl(Expense expense) async {
    if (!expense.hasReceipt) return null;
    try {
      return await _client.storage
          .from(_bucket)
          .createSignedUrl(expense.receiptPath!, 300);
    } catch (e, st) {
      logFailure('receipt link', e, st);
      return null;
    }
  }

  @override
  Future<String?> voiceUrl(Expense expense) async {
    if (!expense.hasVoice) return null;
    try {
      return await _client.storage
          .from(_bucket)
          .createSignedUrl(expense.voicePath!, 300);
    } catch (e, st) {
      logFailure('voice note link', e, st);
      return null;
    }
  }

  @override
  Future<WhatsAppLinkCode> requestWhatsAppCode() => _guard(() async {
    final row = await _client.rpc<dynamic>('create_whatsapp_link_code');
    return WhatsAppLinkCode.fromJson(Map<String, dynamic>.from(row as Map));
  });

  @override
  Future<AppUser> unlinkWhatsApp() => _guard(() async {
    await _client.from('whatsapp_links').delete().eq('profile_id', _uid);
    return _user = _user!.withWhatsApp(null);
  });

  // Company ---------------------------------------------------------------
  @override
  Future<List<Member>> fetchMembers() => _guard(() async {
    final members = await _client
        .from('memberships')
        .select('role, profiles(full_name, email)')
        .eq('company_id', _companyId);
    final invitations = await _client
        .from('invitations')
        .select('email, role')
        .eq('company_id', _companyId);
    return [
      for (final m in members)
        Member(
          name: ((m['profiles'] as Map?)?['full_name'] as String?) ?? '',
          email: ((m['profiles'] as Map?)?['email'] as String?) ?? '',
          role: UserRole.parse(m['role'] as String?),
        ),
      for (final i in invitations)
        Member(
          name: i['email'] as String,
          email: i['email'] as String,
          role: UserRole.parse(i['role'] as String?),
          pending: true,
        ),
    ];
  });

  @override
  Future<void> invite(String email, UserRole role) => _guard(() async {
    try {
      await _client.from('invitations').insert({
        'company_id': _companyId,
        'email': email.trim().toLowerCase(),
        'role': role.name,
        'invited_by': _uid,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw RemboException(tr('Cette personne est déjà invitée.'));
      }
      rethrow;
    }
  });

  @override
  Future<List<PolicyRule>> fetchPolicies() => _guard(() async {
    final rows = await _client.from('policies').select();
    return [for (final r in rows) PolicyRule.fromJson(r)];
  });

  @override
  Future<void> savePolicy(PolicyRule rule) => _guard(
    () => _client.from('policies').upsert({
      'company_id': _companyId,
      'category': rule.category,
      'limit_cents': rule.limitCents,
      'receipt_required': rule.receiptRequired,
    }, onConflict: 'company_id,category'),
  );

  @override
  Future<bool> fetchAutoApprove() => _guard(() async {
    final row = await _client
        .from('companies')
        .select('auto_approve')
        .eq('id', _companyId)
        .maybeSingle();
    return row?['auto_approve'] == true;
  });

  @override
  Future<void> setAutoApprove(bool on) => _guard(
    () => _client.rpc<dynamic>('set_auto_approve', params: {'p_on': on}),
  );

  // Exports ---------------------------------------------------------------
  @override
  Future<ExportBatch> createExport(
    List<String> ids, {
    required String requestId,
    String delimiter = ';',
  }) => _guard(() async {
    final batch = Map<String, dynamic>.from(
      await _client.rpc<dynamic>(
        'create_export',
        params: {
          'p_ids': ids,
          'p_request_id': requestId,
          'p_file_name': CsvExport.fileName(DateTime.now()),
        },
      ) as Map,
    );
    // The rows are read back after the server marked them: the file holds
    // exactly what was exported.
    final rows = await _client
        .from('expenses')
        .select(_expenseColumns)
        .eq('export_batch_id', batch['id'] as String)
        .order('expense_date');
    return ExportBatch.fromJson(
      batch,
      csv: CsvExport.build(
        [for (final r in rows) Expense.fromJson(r)],
        batchId: batch['id'] as String,
        delimiter: delimiter,
      ),
    );
  });

  @override
  Future<List<ExportBatch>> fetchExports() => _guard(() async {
    final rows = await _client
        .from('export_batches')
        .select()
        .order('created_at', ascending: false)
        .limit(50);
    return [for (final r in rows) ExportBatch.fromJson(r)];
  });
}

/// True when Storage refused a write by its row level security rules. For a
/// receipt in its owner's folder, that means its expense was submitted.
bool isLockedReceipt(StorageException e) =>
    e.statusCode == '403' ||
    e.message.toLowerCase().contains('row-level security');
