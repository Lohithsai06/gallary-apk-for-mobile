import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

void main() => runApp(const GalleryApp());

const ink = Color(0xFF252A31);
const muted = Color(0xFF858B93);
const accent = Color(0xFF397A78);
const canvas = Color(0xFFF7F7F5);

class GalleryApp extends StatefulWidget {
  const GalleryApp({super.key});
  @override
  State<GalleryApp> createState() => _GalleryAppState();
}

class _GalleryAppState extends State<GalleryApp> {
  bool dark = false;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Gallery',
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.light),
      appBarTheme: const AppBarTheme(backgroundColor: canvas, foregroundColor: ink, elevation: 0),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: accent.withValues(alpha: .12),
        labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark),
    ),
    home: GalleryHome(onThemeChanged: (v) => setState(() => dark = v), dark: dark),
  );
}

class GalleryHome extends StatefulWidget {
  const GalleryHome({super.key, required this.onThemeChanged, required this.dark});
  final ValueChanged<bool> onThemeChanged;
  final bool dark;
  @override
  State<GalleryHome> createState() => _GalleryHomeState();
}

class _GalleryHomeState extends State<GalleryHome> {
  int tab = 0;
  bool loading = true;
  bool permissionDenied = false;
  bool searching = false;
  String query = '';
  List<AssetPathEntity> albums = [];
  List<AssetEntity> photos = [];
  final Set<String> favorites = {};
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() { super.initState(); loadMedia(); }
  @override
  void dispose() { searchController.dispose(); super.dispose(); }

  Future<void> loadMedia() async {
    if (mounted) setState(() { loading = true; permissionDenied = false; });
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth && !permission.hasAccess) {
      if (mounted) setState(() { permissionDenied = true; loading = false; });
      return;
    }
    final paths = await PhotoManager.getAssetPathList(type: RequestType.common, hasAll: true);
    final all = paths.where((p) => p.isAll).firstOrNull ?? (paths.isNotEmpty ? paths.first : null);
    final items = all == null ? <AssetEntity>[] : await all.getAssetListPaged(page: 0, size: 500);
    if (!mounted) return;
    setState(() { albums = paths; photos = items; loading = false; });
  }

  List<AssetEntity> get visibleAssets {
    Iterable<AssetEntity> result = photos;
    if (tab == 2) result = result.where((a) => a.type == AssetType.video);
    if (tab == 3) result = result.where((a) => favorites.contains(a.id));
    if (query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      result = result.where((a) => (a.title ?? '').toLowerCase().contains(q));
    }
    return result.toList();
  }

  String get pageTitle => const ['Pictures', 'Albums', 'Videos', 'Favorites'][tab];

  @override
  Widget build(BuildContext context) {
    final assets = visibleAssets;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: searching
          ? TextField(controller: searchController, autofocus: true, onChanged: (v) => setState(() => query = v),
              decoration: const InputDecoration(hintText: 'Search your media', border: InputBorder.none))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Gallery', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -.8)),
              Text(pageTitle, style: const TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w500)),
            ]),
        actions: [
          IconButton(tooltip: 'Search', onPressed: () => setState(() {
            searching = !searching;
            if (!searching) { query = ''; searchController.clear(); }
          }), icon: Icon(searching ? Icons.close_rounded : Icons.search_rounded)),
          IconButton(tooltip: 'Settings', onPressed: showSettings, icon: const Icon(Icons.tune_rounded)),
          const SizedBox(width: 6),
        ],
      ),
      body: loading ? const Center(child: CircularProgressIndicator(color: accent))
        : permissionDenied ? _permissionView()
        : tab == 1 ? _albumsView()
        : assets.isEmpty ? _emptyView()
        : RefreshIndicator(color: accent, onRefresh: loadMedia, child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(children: [
                  Text('${assets.length} items', style: const TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (tab == 0) const _LocalBadge(),
                ]),
              )),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(3, 0, 3, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 3, mainAxisSpacing: 3, childAspectRatio: .92),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final asset = assets[index];
                    return MediaTile(asset: asset, favorite: favorites.contains(asset.id),
                      onTap: () => openViewer(asset, assets),
                      onLongPress: () => toggleFavorite(asset));
                  }, childCount: assets.length),
                ),
              ),
            ],
          )),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() { tab = v; searching = false; query = ''; searchController.clear(); }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.photo_outlined), selectedIcon: Icon(Icons.photo), label: 'Photos'),
          NavigationDestination(icon: Icon(Icons.photo_album_outlined), selectedIcon: Icon(Icons.photo_album), label: 'Albums'),
          NavigationDestination(icon: Icon(Icons.play_circle_outline_rounded), selectedIcon: Icon(Icons.play_circle), label: 'Videos'),
          NavigationDestination(icon: Icon(Icons.favorite_border_rounded), selectedIcon: Icon(Icons.favorite), label: 'Favorites'),
        ],
      ),
    );
  }

  Widget _permissionView() => Center(child: Padding(
    padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.photo_library_outlined, size: 64, color: accent),
      const SizedBox(height: 18),
      const Text('Your memories, all in one place', textAlign: TextAlign.center,
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('Allow Gallery to access photos and videos stored on this device. Your media stays on your phone.',
        textAlign: TextAlign.center, style: TextStyle(color: muted, height: 1.5)),
      const SizedBox(height: 22),
      FilledButton.icon(onPressed: () async { await PhotoManager.openSetting(); await loadMedia(); },
        icon: const Icon(Icons.lock_open_rounded), label: const Text('Grant access')),
    ]),
  ));

  Widget _emptyView() => Center(child: Padding(
    padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(tab == 3 ? Icons.favorite_border : Icons.photo_library_outlined, size: 58, color: muted.withValues(alpha: .65)),
      const SizedBox(height: 14),
      Text(tab == 3 ? 'No favorites yet' : 'No media found', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      const Text('Photos and videos on your device will appear here.', textAlign: TextAlign.center,
        style: TextStyle(color: muted)),
      const SizedBox(height: 16),
      TextButton.icon(onPressed: loadMedia, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
    ]),
  ));

  Widget _albumsView() {
    if (albums.isEmpty) return _emptyView();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: albums.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final album = albums[index];
        return FutureBuilder<List<AssetEntity>>(
          future: album.getAssetListPaged(page: 0, size: 1),
          builder: (context, snapshot) {
            final cover = snapshot.data?.firstOrNull;
            return Material(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AlbumPage(album: album))),
                child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(13), child: SizedBox(
                    width: 76, height: 76, child: cover == null
                      ? Container(color: accent.withValues(alpha: .1), child: const Icon(Icons.folder_outlined, color: accent))
                      : AssetThumbnail(asset: cover, fit: BoxFit.cover))),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 5),
                    FutureBuilder<int>(future: album.assetCountAsync, builder: (context, count) => Text('${count.data ?? 0} items', style: const TextStyle(color: muted, fontSize: 12))),
                  ])),
                  const Icon(Icons.chevron_right_rounded, color: muted),
                ])),
              ),
            );
          },
        );
      },
    );
  }

  void toggleFavorite(AssetEntity asset) => setState(() {
    if (!favorites.add(asset.id)) favorites.remove(asset.id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(favorites.contains(asset.id) ? 'Added to favorites' : 'Removed from favorites'),
      duration: const Duration(milliseconds: 900)));
  });

  void openViewer(AssetEntity asset, List<AssetEntity> list) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => MediaViewer(
      asset: asset, assets: list, isFavorite: (a) => favorites.contains(a.id),
      onFavorite: (a) { toggleFavorite(a); },
      onDelete: (a) async {
        final result = await PhotoManager.editor.deleteWithIds([a.id]);
        if (result.isNotEmpty && mounted) { setState(() => photos.removeWhere((x) => result.contains(x.id))); }
      },
    )));
  }

  void showSettings() => showModalBottomSheet(
    context: context, showDragHandle: true, builder: (context) => SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 28), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: widget.dark,
          onChanged: (v) { Navigator.pop(context); widget.onThemeChanged(v); },
          title: const Text('Dark appearance'), subtitle: const Text('Use a darker gallery theme')),
        const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.phone_android_rounded),
          title: Text('Private by design'), subtitle: Text('Your media is read from this device. No account or cloud upload.')),
        const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.info_outline_rounded),
          title: Text('Gallery'), subtitle: Text('Version 1.0.0')),
      ]),
    )),
  );
}

class _LocalBadge extends StatelessWidget {
  const _LocalBadge();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: accent.withValues(alpha: .10), borderRadius: BorderRadius.circular(30)),
    child: const Row(children: [Icon(Icons.shield_outlined, size: 13, color: accent), SizedBox(width: 5),
      Text('ON DEVICE', style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .6))]),
  );
}

class MediaTile extends StatelessWidget {
  const MediaTile({super.key, required this.asset, required this.favorite, required this.onTap, required this.onLongPress});
  final AssetEntity asset;
  final bool favorite;
  final VoidCallback onTap, onLongPress;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap, onLongPress: onLongPress,
    child: Stack(fit: StackFit.expand, children: [
      AssetThumbnail(asset: asset, fit: BoxFit.cover),
      if (asset.type == AssetType.video) Positioned(right: 7, bottom: 7, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
          Text(_duration(asset.duration), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600))]))),
      if (favorite) const Positioned(top: 7, right: 7, child: Icon(Icons.favorite, color: Colors.white, size: 17, shadows: [Shadow(blurRadius: 5)])),
    ]),
  );
}

String _duration(int seconds) {
  final d = Duration(seconds: seconds);
  return '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
}

class AssetThumbnail extends StatelessWidget {
  const AssetThumbnail({super.key, required this.asset, this.fit = BoxFit.cover});
  final AssetEntity asset;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: asset.thumbnailDataWithSize(const ThumbnailSize(420, 420)),
    builder: (context, snapshot) {
      if (snapshot.hasData && snapshot.data != null) return Image.memory(snapshot.data!, fit: fit, gaplessPlayback: true);
      return Container(color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.image_outlined, color: muted)));
    },
  );
}

class AlbumPage extends StatelessWidget {
  const AlbumPage({super.key, required this.album});
  final AssetPathEntity album;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(album.name)),
    body: FutureBuilder<List<AssetEntity>>(
      future: album.getAssetListPaged(page: 0, size: 500),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final assets = snapshot.data!;
        if (assets.isEmpty) return const Center(child: Text('This album is empty'));
        return GridView.builder(padding: const EdgeInsets.all(3), itemCount: assets.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 3, mainAxisSpacing: 3),
          itemBuilder: (_, i) => MediaTile(asset: assets[i], favorite: false,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaViewer(
              asset: assets[i], assets: assets, isFavorite: (_) => false, onFavorite: (_) {},
              onDelete: (_) async {}))), onLongPress: () {}),
      );
      },
    ),
  );
}

class MediaViewer extends StatefulWidget {
  const MediaViewer({super.key, required this.asset, required this.assets, required this.isFavorite, required this.onFavorite, required this.onDelete});
  final AssetEntity asset;
  final List<AssetEntity> assets;
  final bool Function(AssetEntity) isFavorite;
  final ValueChanged<AssetEntity> onFavorite;
  final Future<void> Function(AssetEntity) onDelete;
  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late AssetEntity current = widget.asset;
  bool controls = true;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: GestureDetector(
      onTap: () => setState(() => controls = !controls),
      onHorizontalDragEnd: (details) {
        final i = widget.assets.indexOf(current);
        if (details.primaryVelocity != null && details.primaryVelocity! < 0 && i < widget.assets.length - 1) setState(() => current = widget.assets[i + 1]);
        if (details.primaryVelocity != null && details.primaryVelocity! > 0 && i > 0) setState(() => current = widget.assets[i - 1]);
      },
      child: Stack(children: [
        Center(child: FutureBuilder<File?>(
          future: current.file,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data == null) return const CircularProgressIndicator(color: Colors.white);
            if (current.type == AssetType.video) return _VideoPreview(file: snapshot.data!);
            return InteractiveViewer(minScale: .8, maxScale: 5, child: Image.file(snapshot.data!, fit: BoxFit.contain));
          },
        )),
        if (controls) Positioned(top: 0, left: 0, right: 0, child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: 8, right: 8, bottom: 12),
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black87, Colors.transparent])),
          child: Row(children: [
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white)),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(current.title ?? 'Untitled', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              Text(_dateLabel(current.createDateTime), style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ])),
            IconButton(onPressed: () => widget.onFavorite(current), icon: Icon(widget.isFavorite(current) ? Icons.favorite : Icons.favorite_border, color: Colors.white)),
            IconButton(onPressed: () async {
              final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                title: const Text('Delete this item?'), content: const Text('This removes the item from your device.'),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))]));
              if (ok == true && context.mounted) {
                await widget.onDelete(current);
                if (!context.mounted) return;
                Navigator.pop(context);
              }
            }, icon: const Icon(Icons.delete_outline, color: Colors.white)),
          ]),
        )),
        if (controls) Positioned(bottom: 0, left: 0, right: 0, child: Container(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black87, Colors.transparent])),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            IconButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use your device share menu to share this item.'))),
              icon: const Icon(Icons.share_outlined, color: Colors.white)),
            IconButton(onPressed: () => showModalBottomSheet(context: context, builder: (_) => SafeArea(child: ListTile(
              leading: const Icon(Icons.info_outline), title: const Text('File information'),
              subtitle: Text('${current.title}\n${current.width} × ${current.height}\n${_dateLabel(current.createDateTime)}')))),
              icon: const Icon(Icons.info_outline, color: Colors.white)),
          ]),
        )),
      ]),
    ),
  );
}

String _dateLabel(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.file});
  final File file;
  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  // Video playback is provided by the platform's native gallery intent in this first UI build.
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.videocam_outlined, color: Colors.white, size: 58),
    const SizedBox(height: 12),
    const Text('Video selected', style: TextStyle(color: Colors.white, fontSize: 16)),
    const SizedBox(height: 8),
    Text(widget.file.path.split(Platform.pathSeparator).last,
      style: const TextStyle(color: Colors.white60, fontSize: 11), textAlign: TextAlign.center),
  ]);
}
