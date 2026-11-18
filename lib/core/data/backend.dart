import 'dart:typed_data';

import 'models.dart';

/// Everything the app asks a server. Two implementations: Supabase (real
/// accounts and data) and an in-memory demo used when no project is set.
///
/// Decisions (automatic control, approval, export) are taken behind this
/// interface, never in a screen.
abstract class RemboBackend {
  /// True when data is fictional and lost when the app closes.
  bool get isDemo;

  /// True when real data is kept on this phone only, without a server.
  bool get isLocal => false;

  // Session ---------------------------------------------------------------
  Future<AppUser?> restoreSession();
  Future<AppUser> signIn(String email, String password);

  /// Creates the account. Joins the company that invited [email], if any.
  /// Returns null when the address must be confirmed before signing in.
  Future<AppUser?> signUp({
    required String email,
    required String password,
    required String fullName,
  });
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();

  /// Creates a company; the current user becomes its first manager.
  Future<AppUser> createCompany({
    required String name,
    String ice = '',
    String city = '',
  });

  // Expenses --------------------------------------------------------------
  /// Every expense the current user is allowed to see.
  Future<List<Expense>> fetchExpenses();

  /// Creates the draft when [draft] has an empty id, else updates it.
  /// [createId] is the id to create it with: sending the same request
  /// again then updates the row instead of creating a second one.
  Future<Expense> saveDraft(
    Expense draft, {
    Uint8List? receiptBytes,
    String? receiptName,
    String? createId,
  });
  Future<void> deleteDraft(String id);

  /// Runs the automatic control: the result is approved or needs review.
  Future<Expense> submit(String id);

  /// Manager decision on an expense waiting for review.
  Future<Expense> decide(String id, {required bool approve, String? reason});

  /// Tries to read a receipt. Null when no reader is available.
  Future<ReceiptReading?> readReceipt(Uint8List bytes, String name);

  /// Short-lived link to the receipt picture, when the backend stores one.
  Future<String?> receiptUrl(Expense expense);

  /// Short-lived link to the voice note of a WhatsApp expense.
  Future<String?> voiceUrl(Expense expense) async => null;

  /// A one-time code the person sends as « LIER 123456 » from their
  /// WhatsApp: the server then links the number it came from, so nobody can
  /// link a number they do not hold. Messages from that number become the
  /// person's draft expenses.
  Future<WhatsAppLinkCode> requestWhatsAppCode();

  /// Removes the linked WhatsApp number.
  Future<AppUser> unlinkWhatsApp();

  /// Bytes kept in memory by the demo backend.
  Uint8List? receiptBytes(Expense expense) => null;

  /// Receipt picture kept on the phone, when the backend stores it there.
  Future<Uint8List?> loadReceipt(Expense expense) async => null;

  // Company ---------------------------------------------------------------
  Future<List<Member>> fetchMembers();
  Future<void> invite(String email, UserRole role);
  Future<List<PolicyRule>> fetchPolicies();
  Future<void> savePolicy(PolicyRule rule);

  // Exports ---------------------------------------------------------------
  /// Marks [ids] as exported and returns the batch with its CSV content.
  /// [requestId] makes a retry return the same batch.
  Future<ExportBatch> createExport(
    List<String> ids, {
    required String requestId,
    String delimiter = ';',
  });
  Future<List<ExportBatch>> fetchExports();
}
