# KijaniKiosk Investor Demonstration Script

### 1. Introduction
Welcome. Today, I will demonstrate how KijaniKiosk deploys application updates while maintaining service availability and recovering automatically from failures.

### 2. Show the Two Environments
We use two separate application environments, Blue and Green. Blue runs version 1.3.0, while Green runs version 1.4.0. This separation allows us to prepare and validate a new release without immediately interrupting the active application.

### 3. Demonstrate Deployment
We switch production traffic from Blue to Green through our web proxy. The new version becomes active after its health check succeeds. We can verify that production is now serving version 1.4.0.

### 4. Simulate a Failure
Next, I will deliberately stop the Green application. Our monitoring process checks the production health endpoint every five seconds. Once it detects thirteen consecutive failures, it automatically initiates recovery.

### 5. Demonstrate Automatic Recovery
The system switches traffic back to Blue and verifies the application through the production proxy. In our controlled test, recovery took 65 seconds, meeting the requirement of less than 90 seconds.

### 6. Conclusion
This deployment approach reduces release risk, improves recovery, and gives the engineering team a repeatable way to deliver application updates with greater confidence. Thank you.