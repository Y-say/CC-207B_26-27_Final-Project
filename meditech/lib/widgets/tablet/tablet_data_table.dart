import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Priority level determining whether a column is displayed on narrower widths
enum TabletColumnPriority {
  high, // Always shown
  medium, // Hidden on small tablet / split-screen
  low, // Only on full-width tablet
}

// Definition of a table column
class TabletColumn {
  final String title;
  final TabletColumnPriority priority;
  final double? width;
  final int flex;
  final Alignment alignment;

  const TabletColumn({
    required this.title,
    this.priority = TabletColumnPriority.high,
    this.width,
    this.flex = 1,
    this.alignment = Alignment.centerLeft,
  });
}

// Reusable responsive data table with column priorities, search, filtering, and bulk actions
class TabletDataTable<T> extends StatelessWidget {
  final String searchHint;
  final String? searchQuery;
  final ValueChanged<String>? onSearchChanged;
  final int totalCount;
  final int filteredCount;
  final String countLabel;
  final VoidCallback? onFiltersTap;
  final int activeFilterCount;
  final List<Widget>? headerActions;
  final List<TabletColumn> columns;
  final List<T> items;
  final List<Widget> Function(BuildContext context, T item, int index)
  rowBuilder;
  final ValueChanged<T>? onItemTap;
  final bool selectable;
  final Set<String> selectedIds;
  final String Function(T item)? idGetter;
  final ValueChanged<Set<String>>? onSelectionChanged;
  final List<Widget>? bulkActions;
  final Widget? emptyState;
  final bool showControls;
  final Key? filterButtonKey;


  final bool compactForDrawer;

  final bool expandColumnsToFit;

  const TabletDataTable({
    super.key,
    this.searchHint = 'Search...',
    this.searchQuery,
    this.onSearchChanged,
    required this.totalCount,
    required this.filteredCount,
    this.countLabel = 'items',
    this.onFiltersTap,
    this.activeFilterCount = 0,
    this.headerActions,
    required this.columns,
    required this.items,
    required this.rowBuilder,
    this.onItemTap,
    this.selectable = false,
    this.selectedIds = const {},
    this.idGetter,
    this.onSelectionChanged,
    this.bulkActions,
    this.emptyState,
    this.showControls = true,
    this.filterButtonKey,
    this.compactForDrawer = false,
    this.expandColumnsToFit = true,
  });

  bool _isColumnVisible(TabletColumn col, double availableWidth) {
    if (compactForDrawer) {
      return col.priority == TabletColumnPriority.high;
    }
    if (col.priority == TabletColumnPriority.high) return true;
    if (col.priority == TabletColumnPriority.medium) {
      return availableWidth >= 700;
    }
    return availableWidth >= 950;
  }

  static double _columnMinWidth(TabletColumn col) {
    if (col.width != null) return col.width!;
    return col.flex * 72.0;
  }

  static int _columnFlexWeight(TabletColumn col) {
    if (col.width != null) {
      return col.width!.round().clamp(1, 10000);
    }
    return col.flex.clamp(1, 100);
  }

  Widget _columnSlot({
    required TabletColumn col,
    required Widget child,
    required bool flexFill,
  }) {
    if (flexFill) {
      return Expanded(
        flex: _columnFlexWeight(col),
        child: Align(alignment: col.alignment, child: child),
      );
    }
    return SizedBox(
      width: _columnMinWidth(col),
      child: Align(alignment: col.alignment, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final visibleIndexes = <int>[
          for (int i = 0; i < columns.length; i++)
            if (_isColumnVisible(columns[i], availableWidth)) i,
        ];
        final visibleColumns = visibleIndexes.map((i) => columns[i]).toList();

        const rowPadding = 32.0;
        final minContentWidth =
            rowPadding +
            (selectable ? 44.0 : 0.0) +
            visibleColumns.fold<double>(
              0,
              (sum, c) => sum + _columnMinWidth(c),
            );
        final flexFill =
            expandColumnsToFit && availableWidth.isFinite && availableWidth > 0;
        final needsHorizontalScroll =
            !flexFill && minContentWidth > availableWidth;

        Widget wrapTable(Widget child) {
          if (needsHorizontalScroll) {
            return _HorizontalScrollArea(
              contentWidth: minContentWidth,
              child: child,
            );
          }
          return SizedBox(
            width: flexFill ? availableWidth : minContentWidth,
            child: child,
          );
        }

        final allSelected =
            items.isNotEmpty &&
            idGetter != null &&
            items.every((it) => selectedIds.contains(idGetter!(it)));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Controls Bar (Search, Filter, Count, Action buttons)
            if (showControls)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: LayoutBuilder(
                  builder: (context, barConstraints) {
                    final compactBar =
                        compactForDrawer || barConstraints.maxWidth < 560;
                    final countText = '$filteredCount of $totalCount $countLabel';

                    Widget searchField = Container(
                      height: compactBar ? 42 : 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFD8E8DE),
                          width: 1.2,
                        ),
                      ),
                      child: TextField(
                        onChanged: onSearchChanged,
                        style: GoogleFonts.inter(
                          fontSize: compactBar ? 13 : 13.5,
                          color: const Color(0xFF1A2E22),
                        ),
                        decoration: InputDecoration(
                          hintText: searchHint,
                          hintStyle: GoogleFonts.inter(
                            fontSize: compactBar ? 13 : 13.5,
                            color: const Color(0xFF9CA3AF),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: compactBar ? 17 : 18,
                            color: const Color(0xFF6B7280),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: compactBar ? 10 : 12,
                          ),
                        ),
                      ),
                    );

                    final filterButton = SizedBox(
                      height: compactBar ? 42 : 44,
                      width: compactBar ? 118 : 132,
                      child: ElevatedButton.icon(
                        key: filterButtonKey,
                        onPressed: onFiltersTap,
                        icon: Icon(
                          Icons.filter_alt_outlined,
                          size: compactBar ? 17 : 18,
                          color: Colors.white,
                        ),
                        label: Text(
                          activeFilterCount > 0
                              ? 'Filters ($activeFilterCount)'
                              : 'Filters',
                          style: GoogleFonts.inter(
                            fontSize: compactBar ? 12.5 : 13.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E6B46),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: compactBar ? 8 : 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    );

                    if (compactBar) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(child: searchField),
                              const SizedBox(width: 10),
                              filterButton,
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  countText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: compactBar ? 12 : 13,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                              ...?headerActions,
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(flex: 3, child: searchField),
                        const SizedBox(width: 12),
                        filterButton,
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  countText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              ...?headerActions,
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            // Bulk Actions Bar (if any rows selected)
            if (selectable && selectedIds.isNotEmpty && bulkActions != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      '${selectedIds.length} selected',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 16),
                    ...bulkActions!,
                    const Spacer(),
                    TextButton(
                      onPressed: () => onSelectionChanged?.call({}),
                      child: const Text(
                        'Clear selection',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Table Box
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFD8E8DE),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A1A2E22),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: items.isEmpty
                    ? (emptyState ??
                          const Center(
                            child: Text(
                              'No items found',
                              style: TextStyle(color: Color(0xFF6B7280)),
                            ),
                          ))
                    : wrapTable(
                        Column(
                          children: [
                            // Table Header
                            Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF9FAFB),
                                border: Border(
                                  bottom: BorderSide(
                                    color: Color(0xFFD8E8DE),
                                    width: 1.2,
                                  ),
                                ),
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                child: Row(
                                  children: [
                                  if (selectable) ...[
                                    SizedBox(
                                      width: 36,
                                      child: Checkbox(
                                        value: allSelected,
                                        onChanged: (val) {
                                          if (idGetter == null) return;

                                          if (val == true) {
                                            onSelectionChanged?.call(
                                              items.map(idGetter!).toSet(),
                                            );
                                          } else {
                                            onSelectionChanged?.call({});
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  for (final col in visibleColumns)
                                    _columnSlot(
                                      col: col,
                                      flexFill: flexFill,
                                      child: Text(
                                        col.title,
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF4B5563),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Table Rows
                            Expanded(
                              child: ListView.separated(
                                itemCount: items.length,
                                separatorBuilder: (_, _) => const Divider(
                                  height: 1,
                                  color: Color(0xFFEDF2EE),
                                ),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  final itemId = idGetter?.call(item);
                                  final isSelected =
                                      itemId != null &&
                                      selectedIds.contains(itemId);
                                  final cells = rowBuilder(
                                    context,
                                    item,
                                    index,
                                  );

                                  return InkWell(
                                    onTap: onItemTap != null
                                        ? () => onItemTap!(item)
                                        : null,
                                    child: Container(
                                      width: double.infinity,
                                      height: 56,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      color: isSelected
                                          ? const Color(0xFFF0FDF4)
                                          : Colors.white,
                                      child: Row(
                                        children: [
                                          if (selectable) ...[
                                            SizedBox(
                                              width: 36,
                                              child: Checkbox(
                                                value: isSelected,
                                                onChanged: (val) {
                                                  if (itemId == null) return;

                                                  final next = Set<String>.from(
                                                    selectedIds,
                                                  );

                                                  if (val == true) {
                                                    next.add(itemId);
                                                  } else {
                                                    next.remove(itemId);
                                                  }

                                                  onSelectionChanged?.call(
                                                    next,
                                                  );
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          for (
                                            int i = 0;
                                            i < visibleColumns.length;
                                            i++
                                          )
                                            _columnSlot(
                                              col: visibleColumns[i],
                                              flexFill: flexFill,
                                              child:
                                                  visibleIndexes[i] <
                                                      cells.length
                                                  ? cells[visibleIndexes[i]]
                                                  : const SizedBox.shrink(),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Scrolls wide table content sideways with a scrollbar that is always visible
class _HorizontalScrollArea extends StatefulWidget {
  final double contentWidth;
  final Widget child;

  const _HorizontalScrollArea({
    required this.contentWidth,
    required this.child,
  });

  @override
  State<_HorizontalScrollArea> createState() => _HorizontalScrollAreaState();
}

class _HorizontalScrollAreaState extends State<_HorizontalScrollArea> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = widget.contentWidth > constraints.maxWidth
            ? widget.contentWidth
            : widget.contentWidth;

        return Scrollbar(
          controller: _controller,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: width, child: widget.child),
          ),
        );
      },
    );
  }
}
