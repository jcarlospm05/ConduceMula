import 'package:flutter/material.dart';
import 'package:mule_profiles/mule_profiles.dart';
import 'package:operador/design/mule_truck_logo.dart';

class ProfileSetupScreen extends StatelessWidget {
  const ProfileSetupScreen({
    super.key,
    required this.busy,
    required this.onSelected,
    this.error,
    this.onThemeToggle,
  });
  final bool busy;
  final String? error;
  final VoidCallback? onThemeToggle;
  final Future<void> Function(AppRole) onSelected;

  Future<void> choose(BuildContext context, AppRole role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Configurar como ${role.label}'),
        content: Text(
          role == AppRole.supervisor
              ? 'Esta instalación quedará como Supervisor y no permitirá cambiar a Administrador. Tus registros existentes se conservarán.'
              : 'Esta instalación permitirá usar Administrador y Supervisor. Tus registros existentes se conservarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Atrás'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar perfil'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onSelected(role);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const MuleTruckLogo(),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'MuleAgent',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                ),
                if (onThemeToggle != null)
                  IconButton(
                    tooltip: 'Cambiar tema',
                    onPressed: onThemeToggle,
                    icon: Icon(
                      Theme.of(context).brightness == Brightness.dark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 48),
            const Text(
              'Elige el perfil de esta instalación',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Esta elección inicial se conserva al cerrar la app y al restaurar respaldos.',
            ),
            const SizedBox(height: 24),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => choose(context, AppRole.supervisor),
              icon: const Icon(Icons.badge_outlined),
              label: const Text('Supervisor'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => choose(context, AppRole.administrator),
              icon: const Icon(Icons.manage_accounts_outlined),
              label: const Text('Administrador'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Supervisor: captura, guarda y comparte.\nAdministrador: las mismas funciones y recepción de reportes.',
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    ),
  );
}
