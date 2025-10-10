// lib/core/owner/owner_context.dart  (ou lib/shared/owner_context.dart)

class OwnerContext {
  static final OwnerContext _i = OwnerContext._internal();
  factory OwnerContext() => _i;
  OwnerContext._internal();

  String? _ownerKey; // hoje = userId; no futuro = tenantId
  String get ownerKey => _ownerKey ?? 'local-single-user';

  void setFromUser(String userId) {
    _ownerKey = userId; // chame isso após o login bem-sucedido
  }

  void setFromTenant(String tenantId) {
    _ownerKey = tenantId; // quando migrar para SaaS multi-tenant
  }
}
