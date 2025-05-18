# Vibe

A modern web application built on the Sui blockchain that enables users to create, manage, and interact with various types of content through smart contracts. The application leverages Enoki for authentication and sponsored transactions, providing a seamless user experience.

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

## Tech Stack

- **Frontend**: Next.js 14, React 18, TypeScript
- **Styling**: Tailwind CSS, Radix UI components
- **Blockchain**: Sui blockchain, Mysten Labs tooling
- **Authentication**: Enoki zkLogin, Google OAuth
- **State Management**: React Query, Context API
- **UI/UX**: Framer Motion, Sonner (toasts), Lucide icons
- **Development**: ESLint, Prettier, TypeScript

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

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/sui-overflow.git
   cd sui-overflow
   ```

2. Install dependencies:
   ```bash
   yarn install
   ```

3. Set up environment variables:
   - Copy `.env.template` to `.env`
   - Copy `.env.local.template` to `.env.local`
   - Fill in the required environment variables:
     ```
     # Enoki Configuration
     NEXT_PUBLIC_ENOKI_API_KEY=your_public_key
     ENOKI_SECRET_KEY=your_private_key
     
     # Google OAuth
     NEXT_PUBLIC_GOOGLE_CLIENT_ID=your_google_client_id
     
     # Sui Configuration
     PACKAGE_ID=your_deployed_package_id
     ```

4. Start the development server:
   ```bash
   yarn dev
   ```

5. Open [http://localhost:3000](http://localhost:3000) in your browser

## Project Structure

```
sui-overflow/
├── app/                    # Next.js app directory
│   ├── api/               # API routes
│   ├── auth/              # Authentication pages
│   ├── create/            # Content creation pages
│   ├── profile/           # User profile pages
│   └── upload/            # File upload functionality
├── components/            # Reusable React components
├── contexts/             # React context providers
├── hooks/                # Custom React hooks
├── lib/                  # Utility functions and libraries
├── move/                 # Sui Move smart contracts
├── public/               # Static assets
└── types/                # TypeScript type definitions
```

## Development

- `yarn dev` - Start development server
- `yarn build` - Build for production
- `yarn start` - Start production server
- `yarn lint` - Run ESLint

## Acknowledgments

- [Mysten Labs](https://mystenlabs.com/) for Enoki and Sui blockchain
- [Next.js](https://nextjs.org/) for the React framework
- [Tailwind CSS](https://tailwindcss.com/) for styling

