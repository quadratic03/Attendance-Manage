import 'package:flutter/material.dart';
import '../models/learner.dart';

class PaginatedLearnerList extends StatefulWidget {
  final List<Learner> learners;
  final int itemsPerPage;
  final Widget Function(Learner) itemBuilder;

  const PaginatedLearnerList({
    super.key,
    required this.learners,
    this.itemsPerPage = 10,
    required this.itemBuilder,
  });

  @override
  _PaginatedLearnerListState createState() => _PagzinatedLearnerListState();
}

class _PaginatedLearnerListState extends State<PaginatedLearnerList> {
  int currentPage = 0;

  int get totalPages => (widget.learners.length / widget.itemsPerPage).ceil();

  List<Learner> get currentLearners {
    int start = currentPage * widget.itemsPerPage;
    int end = (currentPage + 1) * widget.itemsPerPage;
    end = end > widget.learners.length ? widget.learners.length : end;
    return widget.learners.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Column(
          children: currentLearners.map(widget.itemBuilder).toList(),
        ),
        if (totalPages > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Color(0xFF003087), size: 20),
                    onPressed: currentPage > 0 ? () => setState(() => currentPage--) : null,
                  ),
                  ...List.generate(totalPages, (index) => TextButton(
                        onPressed: () => setState(() => currentPage = index),
                        child: Text('${index + 1}', style: const TextStyle(fontSize: 14)),
                        style: TextButton.styleFrom(
                          backgroundColor: currentPage == index ? const Color(0xFFFFC107) : null,
                          foregroundColor: currentPage == index ? Colors.black : const Color(0xFF003087),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      )),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Color(0xFF003087), size: 20),
                    onPressed: currentPage < totalPages - 1 ? () => setState(() => currentPage++) : null,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}