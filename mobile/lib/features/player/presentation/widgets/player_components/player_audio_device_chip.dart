import 'package:flutter/material.dart';
import '../../../../../core/audio/audio_device_service.dart';

class PlayerAudioDeviceChip extends StatelessWidget {
  const PlayerAudioDeviceChip({super.key});

  @override
  Widget build(BuildContext context) {
    final deviceService = AudioDeviceService();
    final primaryColor = Theme.of(context).colorScheme.primary;

    return StreamBuilder<AudioOutputDevice>(
      stream: deviceService.deviceStream,
      initialData: deviceService.currentDevice,
      builder: (context, snapshot) {
        final device = snapshot.data ?? deviceService.currentDevice;
        final bool isExternal = device.isExternal;

        return Center(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => deviceService.openOutputSwitcher(),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.35),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      device.icon,
                      size: 16,
                      color: primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        isExternal ? "Écoute sur ${device.name}" : "Ce téléphone (Haut-parleur)",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.9),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 18,
                      color: primaryColor.withValues(alpha: 0.8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
