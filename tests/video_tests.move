#[test_only]
module vibe::video_tests {
    use sui::test_scenario as ts;
    use std::string;
    use vibe::video::{Self, VideoPost, CommentThread, Comment};
    use sui::clock;
    use std::option;
    use sui::table;
    use sui::transfer;
    use sui::object;
    use sui::tx_context;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

    // use walrus::{blob::Blob, , storage_resource::Storage};
    // use walrus::system::{Self, System};

    use walrus::{
    blob::{Self, Blob},
    staked_wal::{Self,StakedWal},
    encoding,
    epoch_parameters::epoch_params_for_testing,
    messages,
    metadata,
    storage_resource::{Self, Storage, split_by_epoch, destroy},
    system::{Self, System},
    system_state_inner,
    test_utils::{ Self, bls_min_pk_sign, signers_to_bitmap}
};

    const CREATOR: address = @0x1;
    const USER: address = @0x2;
    const USER2: address = @0x3;

const RS2: u8 = 1;
const MAX_EPOCHS_AHEAD: u32 = 104;

const ROOT_HASH: u256 = 0xABC;
const SIZE: u64 = 5_000_000;
const EPOCH: u32 = 0;

const N_COINS: u64 = 1_000_000_000;



    fun register_default_blob(
    system: &mut System,
    storage: Storage,
    deletable: bool,
    ctx: &mut TxContext,
): Blob {
    let mut fake_coin = test_utils::mint_frost(N_COINS, ctx);
    // Register a Blob
    let blob_id = blob::derive_blob_id(ROOT_HASH, RS2, SIZE);
    let blob = system.register_blob(
        storage,
        blob_id,
        ROOT_HASH,
        SIZE,
        RS2,
        deletable,
        &mut fake_coin,
        ctx,
    );

    fake_coin.burn_for_testing();
    blob
}

fun get_storage_resource(
    system: &mut System,
    unencoded_size: u64,
    epochs_ahead: u32,
    ctx: &mut TxContext,
): Storage {
    let mut fake_coin = test_utils::mint_frost(N_COINS, ctx);
    let storage_size = encoding::encoded_blob_length(
        unencoded_size,
        RS2,
        system.n_shards(),
    );
    let storage = system.reserve_space(
        storage_size,
        epochs_ahead,
        &mut fake_coin,
        ctx,
    );
    fake_coin.burn_for_testing();
    storage
}

    #[test]
    fun test_create_post() {
        let mut scenario = ts::begin(CREATOR);
        {
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            
            // Create test blob objects
            let ctx = &mut tx_context::dummy();
            let mut system = system::new_for_testing(ctx);
            let storage = get_storage_resource(&mut system, SIZE, 3, ctx);
            let blob_object = register_default_blob(&mut system, storage, false, ctx);
            let blob_object_id = object::id(&blob_object);
            
            let storage2 = get_storage_resource(&mut system, SIZE, 3, ctx);
            let thumbnail_blob = register_default_blob(&mut system, storage2, false, ctx);
            let thumbnail_blob_id = object::id(&thumbnail_blob);

            // Move to next transaction to ensure blob object is created
            ts::next_tx(&mut scenario, CREATOR);

            // Create the post
            video::create_post(
                string::utf8(b"Test video description"),
                string::utf8(b"Test video description"),
                blob_object_id,
                thumbnail_blob_id,
                &clock,
                ts::ctx(&mut scenario)
            );

            // Move to next transaction to ensure object transfer is complete
            ts::next_tx(&mut scenario, CREATOR);

            // Get the post object
            let post = ts::take_shared<VideoPost>(&mut scenario);
            let thread_id = video::get_comment_thread(&post);
            let thread = ts::take_shared<CommentThread>(&mut scenario);
            
            // Test properties
            assert!(video::get_caption(&post) == string::utf8(b"Test video description"), 0);
            assert!(video::get_creator(&post) == CREATOR, 1);
            assert!(video::get_likes(&post) == 0, 2);
            assert!(table::length(video::get_likers(&post)) == 0, 3);
            assert!(table::length(video::get_comments(&thread)) == 0, 4);

            // Return objects to their owners
            transfer::public_share_object(post);
            transfer::public_share_object(thread);
            clock::destroy_for_testing(clock);
            sui::test_utils::destroy(system);
            blob_object.burn();
            thumbnail_blob.burn();
        };
        ts::end(scenario);
    }

    #[test]
    fun test_add_comment() {
        let mut scenario = ts::begin(CREATOR);
        {
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            
            // Create test blob objects
            let ctx = &mut tx_context::dummy();
            let mut system = system::new_for_testing(ctx);
            let storage = get_storage_resource(&mut system, SIZE, 3, ctx);
            let blob_object = register_default_blob(&mut system, storage, false, ctx);
            let blob_object_id = object::id(&blob_object);
            
            let storage2 = get_storage_resource(&mut system, SIZE, 3, ctx);
            let thumbnail_blob = register_default_blob(&mut system, storage2, false, ctx);
            let thumbnail_blob_id = object::id(&thumbnail_blob);
            
            // Move to next transaction to ensure blob object is created
            ts::next_tx(&mut scenario, CREATOR);

            video::create_post(
                string::utf8(b"Test video description"),
                string::utf8(b"Test video description"),
                blob_object_id,
                thumbnail_blob_id,
                &clock,
                ts::ctx(&mut scenario)
            );

            // Move to next transaction to ensure object transfer is complete
            ts::next_tx(&mut scenario, CREATOR);

            // Get the post object
            let post = ts::take_shared<VideoPost>(&mut scenario);
            let thread_id = video::get_comment_thread(&post);
            let mut thread = ts::take_shared<CommentThread>(&mut scenario);

            // Add a comment
            video::add_comment(
                &post,
                &mut thread,
                string::utf8(b"Great video!"),
                option::none(),
                &clock,
                ts::ctx(&mut scenario)
            );

            assert!(table::length(video::get_comments(&thread)) == 1, 0);
            let comment = video::get_comment(&thread, 0);
            assert!(video::get_commenter(comment) == CREATOR, 1);
            assert!(string::length(video::get_comment_text(comment)) == 12, 2); // Length of "Great video!"
            assert!(video::get_comment_likes(comment) == 0, 3);

            // Return objects to their owners
            transfer::public_share_object(post);
            transfer::public_share_object(thread);
            clock::destroy_for_testing(clock);
            sui::test_utils::destroy(system);
            blob_object.burn();
            thumbnail_blob.burn();
        };
        ts::end(scenario);
    }

    #[test]
    fun test_like_post() {
        let mut scenario = ts::begin(CREATOR);
        {
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));

            // Create test blob objects
            let ctx = &mut tx_context::dummy();
            let mut system = system::new_for_testing(ctx);
            let storage = get_storage_resource(&mut system, SIZE, 3, ctx);
            let blob_object = register_default_blob(&mut system, storage, false, ctx);
            let blob_object_id = object::id(&blob_object);
            
            let storage2 = get_storage_resource(&mut system, SIZE, 3, ctx);
            let thumbnail_blob = register_default_blob(&mut system, storage2, false, ctx);
            let thumbnail_blob_id = object::id(&thumbnail_blob);
            
            // Move to next transaction to ensure blob object is created
            ts::next_tx(&mut scenario, CREATOR);

            video::create_post(
                string::utf8(b"Test video description"),
                string::utf8(b"Test video description"),
                blob_object_id,
                thumbnail_blob_id,
                &clock,
                ts::ctx(&mut scenario)
            );

            // Move to next transaction to ensure object transfer is complete
            ts::next_tx(&mut scenario, CREATOR);

            // Get the post object
            let mut post = ts::take_shared<VideoPost>(&mut scenario);
            let thread_id = video::get_comment_thread(&post);
            let mut thread = ts::take_shared<CommentThread>(&mut scenario);

            // Like the post
            video::like_post(&mut post, &clock, ts::ctx(&mut scenario));
            assert!(video::get_likes(&post) == 1, 0);
            assert!(table::length(video::get_likers(&post)) == 1, 1);
            assert!(table::contains(video::get_likers(&post), CREATOR), 2);

            // Unlike the post
            video::unlike_post(&mut post, &clock, ts::ctx(&mut scenario));
            assert!(video::get_likes(&post) == 0, 3);
            assert!(table::length(video::get_likers(&post)) == 0, 4);

            // Return objects to their owners
            transfer::public_share_object(post);
            transfer::public_share_object(thread);
            clock::destroy_for_testing(clock);
            sui::test_utils::destroy(system);
            blob_object.burn();
            thumbnail_blob.burn();
            
        };
        ts::end(scenario);
    }

    #[test]
    fun test_like_comment() {
        let mut scenario = ts::begin(CREATOR);
        {
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));

            // Create test blob objects
            let ctx = &mut tx_context::dummy();
            let mut system = system::new_for_testing(ctx);
            let storage = get_storage_resource(&mut system, SIZE, 3, ctx);
            let blob_object = register_default_blob(&mut system, storage, false, ctx);
            let blob_object_id = object::id(&blob_object);
            
            let storage2 = get_storage_resource(&mut system, SIZE, 3, ctx);
            let thumbnail_blob = register_default_blob(&mut system, storage2, false, ctx);
            let thumbnail_blob_id = object::id(&thumbnail_blob);
            
            // Move to next transaction to ensure blob object is created
            ts::next_tx(&mut scenario, CREATOR);

            video::create_post(
                string::utf8(b"Test video description"),
                string::utf8(b"Test video description"),
                blob_object_id,
                thumbnail_blob_id,
                &clock,
                ts::ctx(&mut scenario)
            );

            // Move to next transaction to ensure object transfer is complete
            ts::next_tx(&mut scenario, CREATOR);

            // Get the post object from sender's inventory
            let post = ts::take_shared<VideoPost>(&mut scenario);
            let thread_id = video::get_comment_thread(&post);
            let mut thread = ts::take_shared<CommentThread>(&mut scenario);

            // Add a comment
            video::add_comment(
                &post,
                &mut thread,
                string::utf8(b"Great video!"),
                option::none(),
                &clock,
                ts::ctx(&mut scenario)
            );

            // Like the comment
            video::like_comment(&post, &mut thread, 0, &clock, ts::ctx(&mut scenario));
            let comment = video::get_comment(&thread, 0);
            assert!(video::get_comment_likes(comment) == 1, 0);
            assert!(table::length(video::get_comment_likers(comment)) == 1, 1);
            assert!(table::contains(video::get_comment_likers(comment), CREATOR), 2);

            // Unlike the comment
            video::unlike_comment(&mut thread, 0, ts::ctx(&mut scenario));
            let comment = video::get_comment(&thread, 0);
            assert!(video::get_comment_likes(comment) == 0, 3);
            assert!(table::length(video::get_comment_likers(comment)) == 0, 4);

            // Return objects to their owners
            transfer::public_share_object(post);
            transfer::public_share_object(thread);
            clock::destroy_for_testing(clock);
            sui::test_utils::destroy(system);
            blob_object.burn();
            thumbnail_blob.burn();
        };
        ts::end(scenario);
    }

    #[test]
    fun test_replies() {
        let mut scenario = ts::begin(CREATOR);
        {
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            // Create test blob objects
            let ctx = &mut tx_context::dummy();
            let mut system = system::new_for_testing(ctx);
            let storage = get_storage_resource(&mut system, SIZE, 3, ctx);
            let blob_object = register_default_blob(&mut system, storage, false, ctx);
            let blob_object_id = object::id(&blob_object);
            
            let storage2 = get_storage_resource(&mut system, SIZE, 3, ctx);
            let thumbnail_blob = register_default_blob(&mut system, storage2, false, ctx);
            let thumbnail_blob_id = object::id(&thumbnail_blob);
            
            // Move to next transaction to ensure blob object is created
            ts::next_tx(&mut scenario, CREATOR);
            
            video::create_post(
                string::utf8(b"Test video description"),
                string::utf8(b"Test video description"),
                blob_object_id,
                thumbnail_blob_id,
                &clock,
                ts::ctx(&mut scenario)
            );

            // Move to next transaction to ensure object transfer is complete
            ts::next_tx(&mut scenario, CREATOR);

            // Get the post object from sender's inventory
            let post = ts::take_shared<VideoPost>(&mut scenario);
            let thread_id = video::get_comment_thread(&post);
            let mut thread = ts::take_shared<CommentThread>(&mut scenario);

            // Add a parent comment
            video::add_comment(
                &post,
                &mut thread,
                string::utf8(b"Parent comment"),
                option::none(),
                &clock,
                ts::ctx(&mut scenario)
            );

            // Add a reply
            video::add_comment(
                &post,
                &mut thread,
                string::utf8(b"Reply to parent"),
                option::some(0),
                &clock,
                ts::ctx(&mut scenario)
            );

            // Get replies to the parent comment
            let replies = video::get_replies(&thread, 0);
            assert!(vector::length(&replies) == 1, 0);
            assert!(vector::borrow(&replies, 0) == &1, 1);

            // Return objects to their owners
            transfer::public_share_object(post);
            transfer::public_share_object(thread);
            clock::destroy_for_testing(clock);
            sui::test_utils::destroy(system);
            blob_object.burn();
            thumbnail_blob.burn();
        };
        ts::end(scenario);
    }

    #[test]
    fun test_create_multiple_posts() {
        let mut scenario = ts::begin(CREATOR);
        {
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));

            // Create first post
            let ctx = &mut tx_context::dummy();
            let mut system = system::new_for_testing(ctx);
            let storage1 = get_storage_resource(&mut system, SIZE, 3, ctx);
            let blob_object1 = register_default_blob(&mut system, storage1, false, ctx);
            let blob_object1_id = object::id(&blob_object1);
            
            let storage2 = get_storage_resource(&mut system, SIZE, 3, ctx);
            let thumbnail_blob1 = register_default_blob(&mut system, storage2, false, ctx);
            let thumbnail_blob1_id = object::id(&thumbnail_blob1);
            
            // Move to next transaction to ensure blob object is created
            ts::next_tx(&mut scenario, CREATOR);
            
            video::create_post(
                string::utf8(b"First video description"),
                string::utf8(b"First video description"),
                blob_object1_id,
                thumbnail_blob1_id,
                &clock,
                ts::ctx(&mut scenario)
            );

            // Move to next transaction to ensure object transfer is complete
            ts::next_tx(&mut scenario, CREATOR);

            // Get the first post object
            let post1 = ts::take_shared<VideoPost>(&mut scenario);
            let thread1_id = video::get_comment_thread(&post1);
            let mut thread1 = ts::take_shared<CommentThread>(&mut scenario);

            // Verify first post properties
            assert!(video::get_caption(&post1) == string::utf8(b"First video description"), 0);
            assert!(video::get_creator(&post1) == CREATOR, 1);

            // Create second post
            let storage3 = get_storage_resource(&mut system, SIZE, 3, ctx);
            let blob_object2 = register_default_blob(&mut system, storage3, false, ctx);
            let blob_object2_id = object::id(&blob_object2);
            
            let storage4 = get_storage_resource(&mut system, SIZE, 3, ctx);
            let thumbnail_blob2 = register_default_blob(&mut system, storage4, false, ctx);
            let thumbnail_blob2_id = object::id(&thumbnail_blob2);
            
            video::create_post(
                string::utf8(b"Second video description"),
                string::utf8(b"Second video description"),
                blob_object2_id,
                thumbnail_blob2_id,
                &clock,
                ts::ctx(&mut scenario)
            );

            // Move to next transaction to ensure object transfer is complete
            ts::next_tx(&mut scenario, CREATOR);

            // Get the second post object
            let post2 = ts::take_shared<VideoPost>(&mut scenario);
            let thread2_id = video::get_comment_thread(&post2);
            let mut thread2 = ts::take_shared<CommentThread>(&mut scenario);

            // Verify second post properties
            assert!(video::get_caption(&post2) == string::utf8(b"Second video description"), 2);
            assert!(video::get_creator(&post2) == CREATOR, 3);

            // Verify posts are distinct
            assert!(object::id(&post1) != object::id(&post2), 4);
            assert!(thread1_id != thread2_id, 5);

            // Return objects to their owners
            transfer::public_share_object(post1);
            transfer::public_share_object(post2);
            transfer::public_share_object(thread1);
            transfer::public_share_object(thread2);
            clock::destroy_for_testing(clock);
            sui::test_utils::destroy(system);
            blob_object1.burn();
            thumbnail_blob1.burn();
            blob_object2.burn();
            thumbnail_blob2.burn();

        };
        ts::end(scenario);
    }

    #[test]
    fun test_multiple_users_interaction() {
        let mut scenario = ts::begin(CREATOR);
        {
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));

            // Create test blob objects
            let ctx = &mut tx_context::dummy();
            let mut system = system::new_for_testing(ctx);
            let storage = get_storage_resource(&mut system, SIZE, 3, ctx);
            let blob_object = register_default_blob(&mut system, storage, false, ctx);
            let blob_object_id = object::id(&blob_object);
            
            let storage2 = get_storage_resource(&mut system, SIZE, 3, ctx);
            let thumbnail_blob = register_default_blob(&mut system, storage2, false, ctx);
            let thumbnail_blob_id = object::id(&thumbnail_blob);
            
            // Move to next transaction to ensure blob object is created
            ts::next_tx(&mut scenario, CREATOR);

            // Creator creates a post
            video::create_post(
                string::utf8(b"Test video description"),
                string::utf8(b"Test video description"),
                blob_object_id,
                thumbnail_blob_id,
                &clock,
                ts::ctx(&mut scenario)
            );

            // Move to next transaction to ensure object transfer is complete
            ts::next_tx(&mut scenario, CREATOR);

            // Get the post object
            let mut post = ts::take_shared<VideoPost>(&mut scenario);
            let thread_id = video::get_comment_thread(&post);
            let mut thread = ts::take_shared<CommentThread>(&mut scenario);

            // Creator adds a comment
            video::add_comment(
                &post,
                &mut thread,
                string::utf8(b"Creator's comment"),
                option::none(),
                &clock,
                ts::ctx(&mut scenario)
            );

            // Switch to USER
            ts::next_tx(&mut scenario, USER);

            // USER likes the post
            video::like_post(&mut post, &clock, ts::ctx(&mut scenario));
            assert!(video::get_likes(&post) == 1, 0);
            assert!(table::contains(video::get_likers(&post), USER), 1);

            // USER adds a comment
            video::add_comment(
                &post,
                &mut thread,
                string::utf8(b"User's comment"),
                option::none(),
                &clock,
                ts::ctx(&mut scenario)
            );

            // Switch to USER2
            ts::next_tx(&mut scenario, USER2);

            // USER2 likes the post
            video::like_post(&mut post, &clock, ts::ctx(&mut scenario));
            assert!(video::get_likes(&post) == 2, 2);
            assert!(table::contains(video::get_likers(&post), USER2), 3);

            // USER2 likes USER's comment
            video::like_comment(&post, &mut thread, 1, &clock, ts::ctx(&mut scenario));
            let user_comment = video::get_comment(&thread, 1);
            assert!(video::get_comment_likes(user_comment) == 1, 4);
            assert!(table::contains(video::get_comment_likers(user_comment), USER2), 5);

            // USER2 tries to like the post again (should have no effect)
            video::like_post(&mut post, &clock, ts::ctx(&mut scenario));
            assert!(video::get_likes(&post) == 2, 6);

            // Switch back to USER
            ts::next_tx(&mut scenario, USER);

            // USER unlikes the post
            video::unlike_post(&mut post, &clock, ts::ctx(&mut scenario));
            assert!(video::get_likes(&post) == 1, 7);
            assert!(!table::contains(video::get_likers(&post), USER), 8);

            // Verify comment thread has both comments
            assert!(table::length(video::get_comments(&thread)) == 2, 9);
            let creator_comment = video::get_comment(&thread, 0);
            assert!(video::get_commenter(creator_comment) == CREATOR, 10);
            assert!(video::get_comment_text(creator_comment) == string::utf8(b"Creator's comment"), 11);

            // Return objects to their owners
            transfer::public_share_object(post);
            transfer::public_share_object(thread);
            clock::destroy_for_testing(clock);
            sui::test_utils::destroy(system);
            blob_object.burn();
            thumbnail_blob.burn();

        };
        ts::end(scenario);
    }

    #[test]
    fun test_getter_functions() {
        let mut scenario = ts::begin(CREATOR);
        {
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));

            // Create test blob objects
            let ctx = &mut tx_context::dummy();
            let mut system = system::new_for_testing(ctx);
            let storage = get_storage_resource(&mut system, SIZE, 3, ctx);
            let blob_object = register_default_blob(&mut system, storage, false, ctx);
            let blob_object_id = object::id(&blob_object);
            
            let storage2 = get_storage_resource(&mut system, SIZE, 3, ctx);
            let thumbnail_blob = register_default_blob(&mut system, storage2, false, ctx);
            let thumbnail_blob_id = object::id(&thumbnail_blob);
            
            // Move to next transaction to ensure blob object is created
            ts::next_tx(&mut scenario, CREATOR);

            // Create a post
            video::create_post(
                string::utf8(b"Test video description"),
                string::utf8(b"Test video description"),
                blob_object_id,
                thumbnail_blob_id,
                &clock,
                ts::ctx(&mut scenario)
            );

            // Move to next transaction to ensure object transfer is complete
            ts::next_tx(&mut scenario, CREATOR);

            // Get the post object
            let mut post = ts::take_shared<VideoPost>(&mut scenario);
            let thread_id = video::get_comment_thread(&post);
            let mut thread = ts::take_shared<CommentThread>(&mut scenario);

            // Test VideoPost getters
            assert!(video::get_caption(&post) == string::utf8(b"Test video description"), 0);
            assert!(video::get_creator(&post) == CREATOR, 1);
            assert!(video::get_likes(&post) == 0, 2);
            assert!(table::length(video::get_likers(&post)) == 0, 3);

            // Add a comment
            video::add_comment(
                &post,
                &mut thread,
                string::utf8(b"Test comment"),
                option::none(),
                &clock,
                ts::ctx(&mut scenario)
            );

            // Add a reply to the comment
            video::add_comment(
                &post,
                &mut thread,
                string::utf8(b"Test reply"),
                option::some(0),
                &clock,
                ts::ctx(&mut scenario)
            );

            // Test CommentThread getters
            assert!(table::length(video::get_comments(&thread)) == 2, 4);

            // Get and test the first comment (parent)
            let parent_comment = video::get_comment(&thread, 0);
            assert!(video::get_comment_id(parent_comment) == 0, 5);
            assert!(video::get_commenter(parent_comment) == CREATOR, 6);
            assert!(video::get_comment_text(parent_comment) == string::utf8(b"Test comment"), 7);
            assert!(option::is_none(video::get_comment_parent_id(parent_comment)), 8);
            assert!(video::get_comment_likes(parent_comment) == 0, 9);
            assert!(table::length(video::get_comment_likers(parent_comment)) == 0, 10);

            // Get and test the second comment (reply)
            let reply_comment = video::get_comment(&thread, 1);
            assert!(video::get_comment_id(reply_comment) == 1, 11);
            assert!(video::get_commenter(reply_comment) == CREATOR, 12);
            assert!(video::get_comment_text(reply_comment) == string::utf8(b"Test reply"), 13);
            assert!(option::is_some(video::get_comment_parent_id(reply_comment)), 14);
            assert!(option::borrow(video::get_comment_parent_id(reply_comment)) == &0, 15);
            assert!(video::get_comment_likes(reply_comment) == 0, 16);
            assert!(table::length(video::get_comment_likers(reply_comment)) == 0, 17);

            // Like the post and verify getters
            video::like_post(&mut post, &clock, ts::ctx(&mut scenario));
            assert!(video::get_likes(&post) == 1, 18);
            assert!(table::length(video::get_likers(&post)) == 1, 19);
            assert!(table::contains(video::get_likers(&post), CREATOR), 20);

            // Like the parent comment and verify getters
            video::like_comment(&post, &mut thread, 0, &clock, ts::ctx(&mut scenario));
            let updated_parent_comment = video::get_comment(&thread, 0);
            assert!(video::get_comment_likes(updated_parent_comment) == 1, 21);
            assert!(table::length(video::get_comment_likers(updated_parent_comment)) == 1, 22);
            assert!(table::contains(video::get_comment_likers(updated_parent_comment), CREATOR), 23);

            // Return objects to their owners
            transfer::public_share_object(post);
            transfer::public_share_object(thread);
            clock::destroy_for_testing(clock);
            sui::test_utils::destroy(system);
            blob_object.burn();
            thumbnail_blob.burn();
        };
        ts::end(scenario);
    }

    #[test]
    fun test_like_other_users_post() {
        let mut scenario = ts::begin(CREATOR);
        {
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));

            // Create test blob objects
            let ctx = &mut tx_context::dummy();
            let mut system = system::new_for_testing(ctx);
            let storage = get_storage_resource(&mut system, SIZE, 3, ctx);
            let blob_object = register_default_blob(&mut system, storage, false, ctx);
            let blob_object_id = object::id(&blob_object);
            
            let storage2 = get_storage_resource(&mut system, SIZE, 3, ctx);
            let thumbnail_blob = register_default_blob(&mut system, storage2, false, ctx);
            let thumbnail_blob_id = object::id(&thumbnail_blob);
            
            // Move to next transaction to ensure blob object is created
            ts::next_tx(&mut scenario, CREATOR);

            // Creator creates a post
            video::create_post(
                string::utf8(b"Test video description"),
                string::utf8(b"Test video description"),
                blob_object_id,
                thumbnail_blob_id,
                &clock,
                ts::ctx(&mut scenario)
            );

            // Move to next transaction to ensure object transfer is complete
            ts::next_tx(&mut scenario, CREATOR);

            // Get the post object
            let mut post = ts::take_shared<VideoPost>(&mut scenario);
            let thread_id = video::get_comment_thread(&post);
            let mut thread = ts::take_shared<CommentThread>(&mut scenario);

            // Switch to USER
            ts::next_tx(&mut scenario, USER);

            // USER likes the post
            video::like_post(&mut post, &clock, ts::ctx(&mut scenario));

            // Verify the like was recorded correctly
            assert!(video::get_likes(&post) == 1, 0);
            assert!(table::contains(video::get_likers(&post), USER), 1);
            assert!(!table::contains(video::get_likers(&post), CREATOR), 2);

            // Return objects to their owners
            transfer::public_share_object(post);
            transfer::public_share_object(thread);
            clock::destroy_for_testing(clock);
            sui::test_utils::destroy(system);
            blob_object.burn();
            thumbnail_blob.burn();
        };
        ts::end(scenario);
    }

    #[test]
    fun test_user_earnings() {
        let mut scenario = ts::begin(CREATOR);
        {
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));

            // Create test blob objects
            let ctx = &mut tx_context::dummy();
            let mut system = system::new_for_testing(ctx);
            let storage = get_storage_resource(&mut system, SIZE, 3, ctx);
            let blob_object = register_default_blob(&mut system, storage, false, ctx);
            let blob_object_id = object::id(&blob_object);
            
            let storage2 = get_storage_resource(&mut system, SIZE, 3, ctx);
            let thumbnail_blob = register_default_blob(&mut system, storage2, false, ctx);
            let thumbnail_blob_id = object::id(&thumbnail_blob);
            
            // Move to next transaction to ensure blob object is created
            ts::next_tx(&mut scenario, CREATOR);

            // Initialize user earnings map
            video::init_user_earnings_map(ts::ctx(&mut scenario));

            // Move to next transaction to ensure map is shared
            ts::next_tx(&mut scenario, CREATOR);

            // Get the shared map
            let mut map = ts::take_shared<video::UserEarningsMap>(&mut scenario);

            // Create a post
            video::create_post(
                string::utf8(b"Test video description"),
                string::utf8(b"Test video description"),
                blob_object_id,
                thumbnail_blob_id,
                &clock,
                ts::ctx(&mut scenario)
            );

            // Move to next transaction to ensure object transfer is complete
            ts::next_tx(&mut scenario, CREATOR);

            // Get the post object
            let mut post = ts::take_shared<VideoPost>(&mut scenario);
            let thread_id = video::get_comment_thread(&post);
            let mut thread = ts::take_shared<CommentThread>(&mut scenario);

            // Verify initial earnings state
            assert!(video::get_user_total_earnings(&map, CREATOR) == 0, 0);
            assert!(video::get_total_earnings(&post) == 0, 1);

            // Switch to USER
            ts::next_tx(&mut scenario, USER);

            // USER tips the post
            let mut payment = coin::mint_for_testing<SUI>(1000, ts::ctx(&mut scenario));
            video::tip_post(&mut post, payment, &mut map, &clock, ts::ctx(&mut scenario));

            // Verify earnings after first tip
            assert!(video::get_user_total_earnings(&map, CREATOR) == 1000, 2);
            assert!(video::get_total_earnings(&post) == 1000, 3);

            // USER tips the post again
            let mut payment2 = coin::mint_for_testing<SUI>(500, ts::ctx(&mut scenario));
            video::tip_post(&mut post, payment2, &mut map, &clock, ts::ctx(&mut scenario));

            // Verify earnings after second tip
            assert!(video::get_user_total_earnings(&map, CREATOR) == 1500, 4);
            assert!(video::get_total_earnings(&post) == 1500, 5);

            // Switch to USER2
            ts::next_tx(&mut scenario, USER2);

            // USER2 tips the post
            let mut payment3 = coin::mint_for_testing<SUI>(2000, ts::ctx(&mut scenario));
            video::tip_post(&mut post, payment3, &mut map, &clock, ts::ctx(&mut scenario));

            // Verify earnings after third tip
            assert!(video::get_user_total_earnings(&map, CREATOR) == 3500, 6);
            assert!(video::get_total_earnings(&post) == 3500, 7);

            // Create another post
            let storage3 = get_storage_resource(&mut system, SIZE, 3, ctx);
            let blob_object2 = register_default_blob(&mut system, storage3, false, ctx);
            let blob_object2_id = object::id(&blob_object2);
            
            let storage4 = get_storage_resource(&mut system, SIZE, 3, ctx);
            let thumbnail_blob2 = register_default_blob(&mut system, storage4, false, ctx);
            let thumbnail_blob2_id = object::id(&thumbnail_blob2);

            // Switch back to CREATOR
            ts::next_tx(&mut scenario, CREATOR);

            video::create_post(
                string::utf8(b"Second video description"),
                string::utf8(b"Second video description"),
                blob_object2_id,
                thumbnail_blob2_id,
                &clock,
                ts::ctx(&mut scenario)
            );

            // Move to next transaction to ensure object transfer is complete
            ts::next_tx(&mut scenario, CREATOR);

            // Get the second post object
            let mut post2 = ts::take_shared<VideoPost>(&mut scenario);
            let thread2_id = video::get_comment_thread(&post2);
            let mut thread2 = ts::take_shared<CommentThread>(&mut scenario);

            // Switch to USER
            ts::next_tx(&mut scenario, USER);

            // USER tips the second post
            let mut payment4 = coin::mint_for_testing<SUI>(3000, ts::ctx(&mut scenario));
            video::tip_post(&mut post2, payment4, &mut map, &clock, ts::ctx(&mut scenario));

            // Verify total earnings across both posts
            assert!(video::get_user_total_earnings(&map, CREATOR) == 6500, 8);
            assert!(video::get_total_earnings(&post) == 3500, 9);
            assert!(video::get_total_earnings(&post2) == 3000, 10);

            // Return objects to their owners
            transfer::public_share_object(post);
            transfer::public_share_object(post2);
            transfer::public_share_object(thread);
            transfer::public_share_object(thread2);
            transfer::public_share_object(map);
            clock::destroy_for_testing(clock);
            sui::test_utils::destroy(system);
            blob_object.burn();
            thumbnail_blob.burn();
            blob_object2.burn();
            thumbnail_blob2.burn();
        };
        ts::end(scenario);
    }
} 