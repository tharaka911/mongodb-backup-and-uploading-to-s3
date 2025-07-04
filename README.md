# MongoDB Backup and S3 Upload Script

A bash script to automate MongoDB database backups and upload them to AWS S3 with comprehensive logging and error handling.

## Features

- ✅ Automated MongoDB backup using `mongodump`
- ✅ Backup compression (ZIP format)
- ✅ Automatic S3 upload
- ✅ Comprehensive logging with timestamps
- ✅ Step-by-step timing metrics
- ✅ Error handling and cleanup
- ✅ Configurable backup retention

## Prerequisites

### System Requirements
- Linux/macOS system (tested on Ubuntu)
- MongoDB tools (`mongodump`)
- AWS CLI v2
- `zip` utility
- Bash shell

### Install MongoDB Tools
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install mongodb-database-tools

# macOS
brew install mongodb/brew/mongodb-database-tools

# CentOS/RHEL
sudo yum install mongodb-database-tools
```

## AWS CLI Configuration on EC2

### Step 1: Install AWS CLI v2
```bash
# Download and install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version
```

### Step 2: Configure AWS CLI

#### Option A: Using IAM Roles (Recommended for EC2)
1. Create an IAM role with S3 permissions:
   ```json
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Action": [
                   "s3:PutObject",
                   "s3:PutObjectAcl",
                   "s3:GetObject",
                   "s3:ListBucket"
               ],
               "Resource": [
                   "arn:aws:s3:::your-bucket-name",
                   "arn:aws:s3:::your-bucket-name/*"
               ]
           }
       ]
   }
   ```

2. Attach the role to your EC2 instance:
   - Go to AWS Console → EC2 → Instances
   - Select your instance → Actions → Security → Modify IAM role
   - Attach the created role

#### Option B: Using Access Keys
```bash
# Configure AWS CLI with access keys
aws configure

# Enter when prompted:
# AWS Access Key ID: [Your Access Key]
# AWS Secret Access Key: [Your Secret Key]
# Default region name: [Your preferred region, e.g., us-east-1]
# Default output format: json
```

#### Option C: Using AWS CLI Profiles
```bash
# Create a named profile
aws configure --profile backup-profile

# Test the configuration
aws s3 ls --profile backup-profile
```

### Step 3: Test AWS CLI Access
```bash
# Test S3 access
aws s3 ls

# Test with specific profile (if using profiles)
aws s3 ls --profile backup-profile

# Test uploading a test file
echo "test" > test.txt
aws s3 cp test.txt s3://your-bucket-name/test.txt
aws s3 rm s3://your-bucket-name/test.txt
rm test.txt
```

## Configuration

### Step 1: Make Script Executable
```bash
# Give executable permission to the script
chmod +x mongo_backup_and_upload.sh

# Verify the permissions (should show -rwxr-xr-x)
ls -la mongo_backup_and_upload.sh
```

**Important**: The script must have executable permissions to run. If you get "Permission denied" errors, it's likely because the script doesn't have execute permissions.

### Step 2: Configure Environment Variables (Optional)
You can use environment variables for sensitive data:

```bash
# Copy the sample environment file
cp .env.sample .env

# Edit the .env file with your actual values
nano .env
```

### Step 3: Edit Configuration Variables
Open `mongo_backup_and_upload.sh` and update the following variables:

```bash
# MongoDB Configuration
MONGO_URI="mongodb+srv://username:password@cluster.mongodb.net/database"
AUTH_DB="admin"  # Usually 'admin' for MongoDB Atlas

# S3 Configuration
S3_BUCKET="your-actual-bucket-name"     # Replace with your S3 bucket name
AWS_PROFILE="default"                   # Or your specific profile name

# Backup Configuration
BACKUP_PARENT_DIR="/home/ubuntu/n-backups"  # Adjust path as needed
```

### Step 3: Create Backup Directory
```bash
# Create the backup directory
sudo mkdir -p /home/ubuntu/n-backups
sudo chown $USER:$USER /home/ubuntu/n-backups
```

## Usage

### Manual Execution
```bash
# Run the backup script
./mongo_backup_and_upload.sh
```

### Automated Execution with Cron
```bash
# Edit crontab
crontab -e

# Add a cron job (example: daily at 2 AM)
0 2 * * * /path/to/mongo_backup_and_upload.sh

# Weekly backup (every Sunday at 3 AM)
0 3 * * 0 /path/to/mongo_backup_and_upload.sh

# Monthly backup (1st day of month at 4 AM)
0 4 1 * * /path/to/mongo_backup_and_upload.sh
```

### Running with Different Profiles
```bash
# If using AWS CLI profiles, update the script's AWS_PROFILE variable
# or set it as an environment variable
AWS_PROFILE=backup-profile ./mongo_backup_and_upload.sh
```

## Script Workflow

1. **Create Backup Directory**: Creates timestamped backup folder
2. **MongoDB Dump**: Runs `mongodump` to backup the database
3. **Compression**: Zips the backup folder for efficient storage
4. **S3 Upload**: Uploads the compressed backup to S3
5. **Cleanup**: Removes local backup files to save disk space
6. **Logging**: Logs all steps with timestamps and timing metrics

## Monitoring and Logs

### Log File Location
```bash
# View the latest log
tail -f /home/ubuntu/n-backups/backup_log.txt

# View recent backup attempts
grep "MongoDB Backup Script" /home/ubuntu/n-backups/backup_log.txt
```

### Log Rotation (Optional)
```bash
# Add to crontab for log rotation
0 0 1 * * find /home/ubuntu/n-backups -name "backup_log.txt" -size +100M -exec mv {} backup_log_$(date +\%Y\%m\%d).txt \; && touch /home/ubuntu/n-backups/backup_log.txt
```

## Troubleshooting

### Common Issues

#### Script Permission Issues
```bash
# Error: "Permission denied" when running the script
# Solution: Make the script executable
chmod +x mongo_backup_and_upload.sh

# Check current permissions
ls -la mongo_backup_and_upload.sh

# The output should show executable permissions like: -rwxr-xr-x
# If it shows -rw-r--r--, the script is not executable

# Alternative: Run with bash explicitly
bash mongo_backup_and_upload.sh
```

#### MongoDB Connection Issues
```bash
# Test MongoDB connection
mongodump --uri="your-mongo-uri" --authenticationDatabase admin --dryRun
```

#### AWS S3 Permission Issues
```bash
# Check AWS CLI configuration
aws sts get-caller-identity

# Test S3 access
aws s3 ls s3://your-bucket-name/
```

#### Disk Space Issues
```bash
# Check available disk space
df -h

# Clean up old backups manually
find /home/ubuntu/n-backups -name "*.zip" -mtime +30 -delete
```

### Error Codes
- Exit code 1: Backup directory creation failed
- Exit code 1: MongoDB dump failed
- Exit code 1: Zip creation failed
- Exit code 1: S3 upload failed
- Exit code 1: Cleanup failed

## Security Best Practices

1. **Never commit credentials**: Keep MongoDB URIs and AWS keys out of version control
2. **Use IAM roles**: Prefer IAM roles over access keys on EC2
3. **Restrict S3 permissions**: Only grant necessary S3 permissions
4. **Encrypt backups**: Consider S3 server-side encryption
5. **Monitor access**: Enable S3 access logging
6. **Rotate credentials**: Regularly rotate MongoDB and AWS credentials

## File Structure

```
fireflies-mongo-s3-backup/
├── README.md                    # This documentation
├── .gitignore                   # Git ignore patterns
├── .env.sample                  # Environment variables template
├── .env                         # Your environment variables (not in git)
└── mongo_backup_and_upload.sh   # Main backup script
```

## License

This project is licensed under the MIT License.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request