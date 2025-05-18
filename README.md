# Vibe

A modern web application built on the Sui blockchain that enables users to create, manage, and interact with various types of content through smart contracts.

## Features

- 🔐 **Authentication**: Secure login using Google OAuth through Enoki's zkLogin
- 💰 **Sponsored Transactions**: Gas-free transactions for users through Enoki
- 📝 **Content Management**: Create and manage video posts
- 🔒 **Encryption**: Support for encrypted content creation
- 📤 **File Upload**: Upload and manage files on the blockchain
- 🎥 **Video Support**: Handle video content with specialized features
- 👤 **User Profiles**: Personalized user profiles and content management
- 🔄 **Real-time Updates**: Dynamic content updates and interactions

## SUI Features
- Shared and owned objects
- zkLogin
- Enoki
- Walrus for storage of video and thumbnails
- SEAL for encryption and decryption of video content
- Walrus Blob Extension

## Smart Contract Architecture

The platform's core functionality is powered by a sophisticated smart contract system built on the Sui blockchain. Here's a detailed breakdown of the architecture:

### Core Data Structures

1. **VideoPost**
   - Main structure for video content
   - Contains creator address, thumbnail, caption, description
   - Manages video blob reference, timestamp, and comment thread
   - Tracks likes and total earnings from tips

2. **EncryptedVideoPost**
   - Enhanced version of VideoPost for premium content
   - Includes subscription service integration
   - Provides access control for private content

3. **CommentThread**
   - Manages video comments and replies
   - Supports nested comment structure
   - Tracks comment likes and interactions

4. **Comment**
   - Individual comment structure
   - Includes commenter address, text, timestamp
   - Supports parent-child relationships for replies
   - Manages comment likes and interactions

### Key Features

1. **Content Management**
   - Create and publish video posts
   - Support for encrypted/premium content
   - Handle video and thumbnail storage
   - Event tracking for content creation

2. **Social Features**
   - Like/unlike system for videos and comments
   - Comprehensive commenting system with nested replies
   - Transparent interaction tracking
   - Event emission for all social actions

3. **Monetization**
   - Direct creator tipping system
   - SUI token integration for payments
   - Global earnings tracking per creator
   - Transparent revenue distribution

4. **Access Control**
   - Public and private video support
   - Subscription-based access for premium content
   - Capability-based security model

### Event System
The contract emits various events for tracking:
- Post creation and updates
- Comment interactions
- Like/unlike actions
- Tipping transactions
- Earnings updates

### Decentralized Advantages
- Direct creator monetization without platform fees
- Transparent interaction tracking
- Immutable content and social interactions
- Privacy options for premium content
- Decentralized content management

## Prerequisites

- Node.js (Latest LTS version recommended)
- Yarn package manager
- Sui CLI (for local development)
- Google Cloud Platform account (for OAuth)
- Enoki account (for authentication and sponsored transactions)



## Acknowledgments

- [Mysten Labs](https://mystenlabs.com/) for Enoki and Sui blockchain
- [Next.js](https://nextjs.org/) for the React framework
- [Tailwind CSS](https://tailwindcss.com/) for styling

