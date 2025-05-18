#[allow(duplicate_alias)]
module vibe::video {
    use sui::event;
    use sui::clock::{Self, Clock};
    use std::option::{Self, Option};
    use std::string::{String};
    use sui::table::{Self, Table};
    // use walrus::{blob::Blob, staked_wal::StakedWal, storage_resource::Storage};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use vibe::subscription::{Self, Service, Cap};

    const EInvalidCap: u64 = 0;

    public struct VideoPost has key, store {
        id: UID,
        creator: address,
        thumbnail_blob_object_id: object::ID,
        caption: String,
        description: String,
        blob_object_id: object::ID,
        timestamp: u64,
        comment_thread: object::ID,
        likes: u64,
        likers: Table<address, bool>,
        total_earnings: u64, // Track total earnings from tips
    }

    public struct EncryptedVideoPost has key, store {
        id: UID,
        creator: address,
        thumbnail_blob_object_id: object::ID,
        caption: String,
        description: String,
        blob_object_id: object::ID,
        timestamp: u64,
        comment_thread: object::ID,
        likes: u64,
        likers: Table<address, bool>,
        total_earnings: u64,
        subscription_service_id: object::ID,
    }

    public struct CommentThread has key, store {
        id: UID,
        comments: Table<u64, Comment>,
        next_comment_id: u64,
    }

    public struct Comment has store {
        id: u64,
        commenter: address,
        text: String,
        timestamp: u64,
        parent_comment_id: Option<u64>,
        likes: u64,
        likers: Table<address, bool>,
    }

    public struct CommentAddedEvent has copy, drop, store {
        post_id: object::ID,
        comment_id: u64,
        commenter: address,
        text: String,
        timestamp: u64,
        parent_comment_id: Option<u64>,
    }

    public struct CommentLikeEvent has copy, drop, store {
        post_id: object::ID,
        comment_id: u64,
        liker: address,
        timestamp: u64,
    }

    public struct LikeEvent has copy, drop, store {
        post_id: object::ID,
        liker: address,
        timestamp: u64,
    }

    public struct UnlikeEvent has copy, drop, store {
        post_id: object::ID,
        unliker: address,
        timestamp: u64,
    }

    public struct TipEvent has copy, drop, store {
        post_id: object::ID,
        tipper: address,
        amount: u64,
        timestamp: u64,
    }

    public struct PostCreatedEvent has copy, drop, store {
        post_id: object::ID,
        creator: address,
        caption: String,
        description: String,
        timestamp: u64,
        blob_object_id: object::ID,
        thumbnail_blob_object_id: object::ID,
    }

    public struct EncryptedPostCreatedEvent has copy, drop, store {
        post_id: object::ID,
        creator: address,
        caption: String,
        description: String,
        timestamp: u64,
        subscription_service_id: object::ID,
        blob_object_id: object::ID,
        thumbnail_blob_object_id: object::ID,
    }

    public struct UserEarningsMap has key, store {
        id: UID,
        earnings: Table<address, u64>,
    }

    public struct UserEarningsUpdatedEvent has copy, drop, store {
        user: address,
        new_total: u64,
        timestamp: u64,
    }

    public fun create_post(
        caption: String,
        description: String,
        blob_object: object::ID,
        thumbnail_blob_object: object::ID,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let creator = tx_context::sender(ctx);
        let timestamp = clock::timestamp_ms(clock);

        let thread = CommentThread {
            id: object::new(ctx),
            comments: table::new(ctx),
            next_comment_id: 0,
        };

        let thread_id = object::id(&thread);

        let post = VideoPost {
            id: object::new(ctx),
            creator,
            thumbnail_blob_object_id: thumbnail_blob_object,
            caption,
            description,
            blob_object_id: blob_object,
            timestamp,
            comment_thread: thread_id,
            likes: 0,
            likers: table::new(ctx),
            total_earnings: 0, // Initialize with zero earnings
        };

        // let post_address = object::uid_to_address(&post.id);

        // Transfer blob objects to VideoPost
        // transfer::public_transfer(blob_object, post_address);
        // transfer::public_transfer(thumbnail_blob_object, post_address);

        // Emit post creation event
        event::emit(PostCreatedEvent {
            post_id: object::id(&post),
            creator,
            caption,
            description,
            timestamp,
            blob_object_id: blob_object,
            thumbnail_blob_object_id: thumbnail_blob_object,
        });

        // Make both objects shared so anyone can interact with them
        transfer::share_object(post);
        transfer::share_object(thread);
    }

    public fun create_encrypted_post(
        caption: String,
        description: String,
        blob_object: object::ID,
        thumbnail_blob_object: object::ID,
        service: &mut Service,
        cap: &Cap,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(subscription::get_service_id(cap) == object::id(service), EInvalidCap);

        let creator = tx_context::sender(ctx);
        let timestamp = clock::timestamp_ms(clock);

        let thread = CommentThread {
            id: object::new(ctx),
            comments: table::new(ctx),
            next_comment_id: 0,
        };

        let thread_id = object::id(&thread);

        // Publish the blob ID to the subscription service

        // subscription::publish(service, cap, walrus::blob::blob_id(blob_object));
        // subscription::publish(service, cap, walrus::blob::blob_id(thumbnail_blob_object));

        let post = EncryptedVideoPost {
            id: object::new(ctx),
            creator,
            thumbnail_blob_object_id: thumbnail_blob_object,
            caption,
            description,
            blob_object_id: blob_object,
            timestamp,
            comment_thread: thread_id,
            likes: 0,
            likers: table::new(ctx),
            total_earnings: 0,
            subscription_service_id: object::id(service),
        };

        // Emit encrypted post creation event
        event::emit(EncryptedPostCreatedEvent {
            post_id: object::id(&post),
            creator,
            caption,
            description,
            timestamp,
            subscription_service_id: object::id(service),
            blob_object_id: blob_object,
            thumbnail_blob_object_id: thumbnail_blob_object,
        });
        
        // Make both objects shared so anyone can interact with them
        transfer::share_object(post);
        transfer::share_object(thread);
    }

    public fun add_comment(
        post: &VideoPost,
        thread: &mut CommentThread,
        text: String,
        parent_comment_id: Option<u64>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let commenter = tx_context::sender(ctx);
        let timestamp = clock::timestamp_ms(clock);
        let comment_id = thread.next_comment_id;
        thread.next_comment_id = thread.next_comment_id + 1;

        let comment = Comment { 
            id: comment_id,
            commenter, 
            text, 
            timestamp,
            parent_comment_id,
            likes: 0,
            likers: table::new(ctx),
        };
        table::add(&mut thread.comments, comment_id, comment);

        event::emit(CommentAddedEvent {
            post_id: object::id(post),
            comment_id,
            commenter,
            text,
            timestamp,
            parent_comment_id,
        });
    }

    public fun like_comment(
        post: &VideoPost,
        thread: &mut CommentThread,
        comment_id: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let liker = tx_context::sender(ctx);
        let timestamp = clock::timestamp_ms(clock);

        let comment = table::borrow_mut(&mut thread.comments, comment_id);

        // Check if user has already liked the comment
        if (table::contains(&comment.likers, liker)) {
            return
        };

        // Add like and liker
        comment.likes = comment.likes + 1;
        table::add(&mut comment.likers, liker, true);

        event::emit(CommentLikeEvent {
            post_id: object::id(post),
            comment_id,
            liker,
            timestamp,
        });
    }

    public fun unlike_comment(
        thread: &mut CommentThread,
        comment_id: u64,
        ctx: &mut TxContext
    ) {
        let unliker = tx_context::sender(ctx);

        let comment = table::borrow_mut(&mut thread.comments, comment_id);

        // Remove the unliker if they exist
        if (table::contains(&comment.likers, unliker)) {
            table::remove(&mut comment.likers, unliker);
            comment.likes = comment.likes - 1;
        };
    }

    public fun like_post(
        post: &mut VideoPost,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let liker = tx_context::sender(ctx);
        let timestamp = clock::timestamp_ms(clock);

        // Check if user has already liked the post
        if (table::contains(&post.likers, liker)) {
            return
        };

        // Add like and liker
        post.likes = post.likes + 1;
        table::add(&mut post.likers, liker, true);

        event::emit(LikeEvent {
            post_id: object::id(post),
            liker,
            timestamp,
        });
    }

    public fun unlike_post(
        post: &mut VideoPost,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let unliker = tx_context::sender(ctx);
        let timestamp = clock::timestamp_ms(clock);

        // Remove the unliker if they exist
        if (table::contains(&post.likers, unliker)) {
            table::remove(&mut post.likers, unliker);
            post.likes = post.likes - 1;

            event::emit(UnlikeEvent {
                post_id: object::id(post),
                unliker,
                timestamp,
            });
        };
    }

    // Helper function to get a comment by ID
    public fun get_comment(thread: &CommentThread, comment_id: u64): &Comment {
        table::borrow(&thread.comments, comment_id)
    }

    // Helper function to get all replies to a comment
    public fun get_replies(thread: &CommentThread, parent_id: u64): vector<u64> {
        let mut replies = vector::empty<u64>();
        let mut i = 0;
        let len = table::length(&thread.comments);
        while (i < len) {
            let comment = table::borrow(&thread.comments, i);
            if (option::is_some(&comment.parent_comment_id) && 
                option::borrow(&comment.parent_comment_id) == &parent_id) {
                vector::push_back(&mut replies, comment.id);
            };
            i = i + 1;
        };
        replies
    }

    // Public getter for comment_thread field
    public fun get_comment_thread(post: &VideoPost): object::ID {
        post.comment_thread
    }

    // Public getters for VideoPost fields
    public fun get_thumbnail_blob_object_id(post: &VideoPost): object::ID {
        post.thumbnail_blob_object_id
    }

    public fun get_caption(post: &VideoPost): &String {
        &post.caption
    }

    public fun get_description(post: &VideoPost): &String {
        &post.description
    }

    public fun get_blob_object_id(post: &VideoPost): object::ID {
        post.blob_object_id
    }

    public fun get_creator(post: &VideoPost): address {
        post.creator
    }

    public fun get_likes(post: &VideoPost): u64 {
        post.likes
    }

    public fun get_likers(post: &VideoPost): &Table<address, bool> {
        &post.likers
    }

    // Public getter for CommentThread fields
    public fun get_comments(thread: &CommentThread): &Table<u64, Comment> {
        &thread.comments
    }

    // Public getters for Comment fields
    public fun get_comment_id(comment: &Comment): u64 {
        comment.id
    }

    public fun get_commenter(comment: &Comment): address {
        comment.commenter
    }

    public fun get_comment_text(comment: &Comment): &String {
        &comment.text
    }

    public fun get_comment_timestamp(comment: &Comment): u64 {
        comment.timestamp
    }

    public fun get_comment_parent_id(comment: &Comment): &Option<u64> {
        &comment.parent_comment_id
    }

    public fun get_comment_likes(comment: &Comment): u64 {
        comment.likes
    }

    public fun get_comment_likers(comment: &Comment): &Table<address, bool> {
        &comment.likers
    }

    public(package) fun init_user_earnings_map(ctx: &mut TxContext) {
        let map = UserEarningsMap {
            id: object::new(ctx),
            earnings: table::new(ctx),
        };
        transfer::share_object(map);
    }

    fun init(ctx: &mut TxContext) {
        init_user_earnings_map(ctx);
    }

    public fun tip_post(
        post: &mut VideoPost,
        payment: Coin<SUI>,
        map: &mut UserEarningsMap,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let tipper = tx_context::sender(ctx);
        let timestamp = clock::timestamp_ms(clock);
        let amount = coin::value(&payment);

        // Convert coin to balance for transfer
        let balance = coin::into_balance(payment);
        transfer::public_transfer(coin::from_balance(balance, ctx), post.creator);

        // Update post's total earnings
        post.total_earnings = post.total_earnings + amount;

        // Update creator's total earnings in the map
        if (!table::contains(&map.earnings, post.creator)) {
            table::add(&mut map.earnings, post.creator, 0);
        };
        {
            let current_earnings = table::borrow_mut(&mut map.earnings, post.creator);
            *current_earnings = *current_earnings + amount;
        }; // current_earnings is dropped here

        event::emit(TipEvent {
            post_id: object::id(post),
            tipper,
            amount,
            timestamp,
        });

        event::emit(UserEarningsUpdatedEvent {
            user: post.creator,
            new_total: *table::borrow(&map.earnings, post.creator),
            timestamp,
        });
    }

    // View function to check total earnings for a user
    public fun get_user_total_earnings(map: &UserEarningsMap, user: address): u64 {
        if (table::contains(&map.earnings, user)) {
            *table::borrow(&map.earnings, user)
        } else {
            0
        }
    }

    // View function to check total earnings
    public fun get_total_earnings(post: &VideoPost): u64 {
        post.total_earnings
    }
}
