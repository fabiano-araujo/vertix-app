import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/comment_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/models/comment_model.dart';

/// Comments Bottom Sheet (TikTok style)
class CommentsSheet extends StatefulWidget {
  final int episodeId;

  const CommentsSheet({super.key, required this.episodeId});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _commentService = CommentService();
  final _authService = AuthService();
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();

  List<CommentModel> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  int? _replyingTo;
  String? _replyingToUsername;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Load more comments when near bottom
      _loadMoreComments();
    }
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);

    final response = await _commentService.getComments(widget.episodeId);

    setState(() {
      _comments = response.data;
      _isLoading = false;
    });
  }

  Future<void> _loadMoreComments() async {
    if (_isLoading) return;

    final response = await _commentService.getComments(
      widget.episodeId,
      offset: _comments.length,
    );

    if (response.data.isNotEmpty) {
      setState(() {
        _comments.addAll(response.data);
      });
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    // Check if authenticated
    if (!await _authService.isAuthenticated()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faca login para comentar')),
      );
      return;
    }

    setState(() => _isSending = true);

    CommentResponse response;
    if (_replyingTo != null) {
      response = await _commentService.replyToComment(_replyingTo!, text);
    } else {
      response = await _commentService.createComment(widget.episodeId, text);
    }

    setState(() => _isSending = false);

    if (response.success && response.data != null) {
      _commentController.clear();
      _cancelReply();

      if (_replyingTo == null) {
        // Add new comment to top
        setState(() {
          _comments.insert(0, response.data!);
        });
      } else {
        // Reload to show reply
        _loadComments();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message ?? 'Erro ao enviar comentario')),
      );
    }
  }

  void _startReply(CommentModel comment) {
    setState(() {
      _replyingTo = comment.id;
      _replyingToUsername = comment.user?.displayName ?? 'Usuario';
    });
    // Focus on text field
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
      _replyingToUsername = null;
    });
  }

  Future<void> _toggleLike(CommentModel comment) async {
    final response = await _commentService.toggleLike(comment.id);

    if (response.success) {
      setState(() {
        final index = _comments.indexWhere((c) => c.id == comment.id);
        if (index != -1) {
          _comments[index] = _comments[index].copyWith(
            isLiked: response.isLiked,
            likesCount: response.likesCount,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withAlpha(100),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_comments.length} comentarios',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Comments list
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      )
                    : _comments.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _comments.length,
                            itemBuilder: (context, index) =>
                                _buildComment(_comments[index]),
                          ),
              ),

              // Reply indicator
              if (_replyingTo != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppColors.surfaceLight,
                  child: Row(
                    children: [
                      Text(
                        'Respondendo a $_replyingToUsername',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _cancelReply,
                        icon: const Icon(Icons.close, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

              // Input field
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(color: AppColors.textSecondary.withAlpha(50)),
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: _replyingTo != null
                                ? 'Escreva uma resposta...'
                                : 'Adicione um comentario...',
                            hintStyle: TextStyle(color: AppColors.textSecondary),
                            filled: true,
                            fillColor: AppColors.surfaceLight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isSending ? null : _sendComment,
                        icon: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            : const Icon(Icons.send, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            'Nenhum comentario ainda',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Seja o primeiro a comentar!',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildComment(CommentModel comment) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.surfaceLight,
            backgroundImage: comment.user?.photo != null
                ? CachedNetworkImageProvider(comment.user!.photo!)
                : null,
            child: comment.user?.photo == null
                ? Text(
                    comment.user?.initials ?? '?',
                    style: const TextStyle(fontSize: 12),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username and time
                Row(
                  children: [
                    Text(
                      comment.user?.displayName ?? 'Usuario',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      comment.timeAgo,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (comment.isPinned) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.push_pin, size: 12, color: AppColors.primary),
                    ],
                  ],
                ),
                const SizedBox(height: 4),

                // Comment text
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 14, height: 1.3),
                ),
                const SizedBox(height: 8),

                // Actions
                Row(
                  children: [
                    // Like button
                    InkWell(
                      onTap: () => _toggleLike(comment),
                      child: Row(
                        children: [
                          Icon(
                            comment.isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 16,
                            color: comment.isLiked
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          if (comment.likesCount > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              comment.formattedLikes,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Reply button
                    InkWell(
                      onTap: () => _startReply(comment),
                      child: Text(
                        'Responder',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // Replies count
                    if (comment.repliesCount > 0) ...[
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: () => _showReplies(comment),
                        child: Text(
                          'Ver ${comment.repliesCount} respostas',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // Nested replies (if loaded)
                if (comment.replies.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      children: comment.replies
                          .map((reply) => _buildReply(reply))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReply(CommentModel reply) {
    return Container(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.surfaceLight,
            backgroundImage: reply.user?.photo != null
                ? CachedNetworkImageProvider(reply.user!.photo!)
                : null,
            child: reply.user?.photo == null
                ? Text(
                    reply.user?.initials ?? '?',
                    style: const TextStyle(fontSize: 10),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      reply.user?.displayName ?? 'Usuario',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      reply.timeAgo,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  reply.content,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    InkWell(
                      onTap: () => _toggleLike(reply),
                      child: Row(
                        children: [
                          Icon(
                            reply.isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 14,
                            color: reply.isLiked
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          if (reply.likesCount > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              reply.formattedLikes,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => _startReply(reply),
                      child: Text(
                        'Responder',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showReplies(CommentModel comment) async {
    final response = await _commentService.getReplies(comment.id);

    if (response.success && response.data.isNotEmpty) {
      setState(() {
        final index = _comments.indexWhere((c) => c.id == comment.id);
        if (index != -1) {
          _comments[index] = _comments[index].copyWith(
            replies: response.data,
          );
        }
      });
    }
  }
}
