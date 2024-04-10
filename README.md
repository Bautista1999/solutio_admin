# Solutio back-end canisters overview
<p align="center">
<img src="LogoSol3.png" alt="Alt Text" width="200">
</p>

[Solutio](https://xh6qb-uyaaa-aaaal-acuaq-cai.icp0.io/) is a decentralized application built on the [Internet Computer](https://internetcomputer.org/), enabling users to share innovative ideas, collaborate on developments, and pledge funding. It bridges the gap between idea generation and implementation, leveraging the power of the blockchain to bring solutions to life.

## Key functionalities of the backend

In addressing the complexities of Solutio's platform development, we've acknowledged the need for dedicated canister solutions that are specifically tailored to tackle various operational challenges. These canister solutions—namely the Admin Canister and the Escrow Canister—are architectural components designed to enhance the functionality, security, and efficiency of the Solutio infrastructure.

1. **Admin Canister**: Serves as a centralized controller for critical administrative tasks, ensuring sensitive data management, user reputation calculations, pledges management, and secure notifications.

2. **Escrow Canister**: Focuses on managing escrow processes, facilitating secure transactions, and providing detailed records of user fund allocations.

The front-end establish a framework utilizing [ICRC-2](https://github.com/dfinity/ICRC-1/tree/aa82e52aaa74cc7c5f6a141e30b708bf42ede1e3/standards/ICRC-2) capabilities for users to approve users transactions to the Escrow Canister. And this canister also uses ICRC-2 capabilities to transfer tokens.

## Key components / structure
This part of the project is structured completely into the backend-end components of the whole platform (excluding our juno satellite), with Motoko being the primary language used. The front-end section of the project is detailed [here](https://github.com/Bautista1999/solut/blob/main/README.md), and is hosted by [Juno](juno.build).

### Project's folder overview

```
solutio_admin
│
├── README.md
├── dfx.json
├── package-lock.json
├── package.json
│
├── src
│   ├── declarations
│   │   ├── solutio_admin_backend
│   │   │   └── [Candid and JavaScript Binding Files]
│   │   └── solutio_admin_frontend
│   │       └── [Candid and JavaScript Binding Files]
│   │
│   └── solutio_admin_backend
│      ├── juno.bridge.mo
│      ├── notifications.mo
│      ├── icrc.bridge.mo
│      ├── encoding.mo
│      ├── validate.mo
│      ├── main.mo
│      └── types.mo
└── webpack.config.js
```

### Project's folder walkthrough
- `src/declarations`
contains the generated declarations for interacting with the canisters.
- `src/solutio_admin_backend`
Contains Motoko source code for the backend logic of Solutio. This contains:
  - `juno.bridge.mo`: A bridge module for interacting with the backend juno canister. This canister is the satellite of Solutio, where all of our database is located. Specifically, this files implements juno key functions to interact with the satellite. [Here](https://dashboard.internetcomputer.org/canister/svftd-daaaa-aaaal-adr3a-cai) you can see the icp dashboard of the canister. You can see the documentation of its functions on these links:
    1. [setJunoDoc](https://forum.solutio.one/-152/setjunodoc-documentation)(): function to set documents in Juno.  
    
    2. [setManyJunoDocs](https://forum.solutio.one/-153/setmanyjunodocs-documentation)(): set many documents in Juno.  
    
    3. [updateJunoDoc](https://forum.solutio.one/-160)(): function to update documents in Juno.  
    
    4. [updateManyJunoDocs](https://forum.solutio.one/-161/updatemanyjunodocs-documentation)(): update many documents in Juno.  
    
    5. [getJunoDoc](https://forum.solutio.one/-154/getjunodoc-documentation)(): function to get a document from juno. 
    
    6. [getManyJunoDocs](https://forum.solutio.one/-155/getmanyjunodocs-documentation)(): get many documents in Juno. 
      
    7. [listJunoDocs](https://forum.solutio.one/-156/listjunodocs-documentation)(): function to get a list of documents in Juno. 
    
    8. [deleteJunoDoc](https://forum.solutio.one/-158/deletejunodoc-documentation)(): delete docs in Juno. 
    
    9. [deleteManyJunoDocs](https://forum.solutio.one/-159/deletemanyjunodocs-documentation)(): function to delete docs in Juno.
  
  - `main.mo`: The main entry point of the backend canister. Here the public functions are located.
    1. [pledgeCreate()](https://forum.solutio.one/-164): This function is used to initiate a new Pledge for a requested feature. It verifies the existence and eligibility of the feature for new pledges before adding the pledge to the "pledges_active" database table. 
    
    2. [pledgeEdit()](https://forum.solutio.one/-165): Used to edit existing pledges. Has to check if the pledge exists and can be edited, has to check if the pledge is part of a feature that is already locked (being delivered as a solution), and then updates the amount. 
    
    3. [solutionSubmit()](https://forum.solutio.one/-166/solutionsubmit-documentation): This endpoint marks a Solution as completed and initiates the approval process by the pledgers. It updates the solution status and notifies followers while preparing the pledges for approval verification. 
    
    3. [updateSolutionStatus](https://forum.solutio.one/-176/updatesolutionstatus-documentation): Changes the status of a solution in the `solution_status` collection, through the admin canister. 
    
    5. [pledgeApprovedVerify](https://forum.solutio.one/-167/pledgeapprovedverify-documentation)](): This function checks the legitimacy of an approved pledge by examining the ICRC Ledger and updates the pledge's status based on the verification result.
    
    6. [pledgeApprovedCounter](https://forum.solutio.one/-168/pledgeapprovecounter-documentation)](): It maintains an accurate count of approved pledges by altering the "total approved" amount for the Solution whenever there is a change.
       
    8. [followersCounter()](https://forum.solutio.one/-169/followerscounter-documentation): This function is triggered when there is a change in followers or likes. It updates the "total likes/followers field" by incrementing or decrementing the count accordingly.
       
    7. [ideasCounter()](https://forum.solutio.one/-170/ideascounter-documentation): This endpoint is responsible for tracking the creation and deletion of ideas within Solutio. It adjusts the total ideas count by either increasing or decreasing it based on the event
       
    7. [pledgesCounter()](https://forum.solutio.one/-171/pledgescounter-documentation): Whenever a pledge is made, this function recalculates the total pledges by adding or subtracting the pledge amount. It ensures that the total reflects the sum of all pledges across all features, ideas, and the entire Solutio platform.
       
    7. [transfersBuildersCounter](https://forum.solutio.one/-172/transfersbuilderscounter-documentation): This function is activated whenever a reward is paid out. It updates the "total builder revenue" variable by adding or subtracting the reward amount.
       
    7. [solutionsCompletedCounter()](https://forum.solutio.one/-173/solutionscompletedcounter-documentation): Called upon the completion of a project, this function increments or decrements the total number of completed projects within Solutio.
       
    7. [userRevenueCounter()](https://forum.solutio.one/-174/userrevenuecounter-documentation): Tracks and updates the "total earned" amount for users as they earn revenue through the platform.
       
    7. [ideaRevenueCounter()](https://forum.solutio.one/-175/idearevenuecounter-documentation): Monitors and adjusts the "total earned" from ideas whenever a user makes a payment.
       
    9. [solutionApproveEdit()](https://forum.solutio.one/-179/solutionapproveedit-documentation): Is designed to edit an existing approval of a pledge made towards a solution on the Solutio platform. It allows for the adjustment of the approved amount in cases where the initial approval needs to be modified.
   
    10. [solutionReject()](https://forum.solutio.one/-178/solutionreject-documentation): Crafted to facilitate the rejection of a solution submitted within the Solutio platform. It's designed to reset the "paid" value of pledges associated with the rejected solution to 0, update the pledge status to reflect the rejection, and make necessary adjustments to the total approved amount and user reputation accordingly. This function is critical for maintaining the integrity and accuracy of financial transactions and user engagements on the platform, especially in cases where a submitted solution does not meet the required standards or expectations..
        
    12. [deleteElement()](https://forum.solutio.one/-182/deleteelement-documentation): Designed to ensure comprehensive removal of an element (e.g., idea, user, solution, or feature) and all its associated documents within the Solutio platform. This function aims to maintain data integrity and cleanliness by eliminating not just the primary document but also related documents like revenue counters, pledges, search indexes, and follower counts.
       
  - `types.mo`: Defines Motoko types used across the backend. It helps in maintaining a clean codebase by abstracting type definitions into a separate module.
  - `notifications.mo`: Defines the necessary functions to implement notifications within Solutio. Its main purpose its to work as the controller functions that creates and handles notifications within the platform.
    
    9. [createPersonalNotification()](https://forum.solutio.one/-180/createpersonalnotification-documentation): Serves the critical role of creating personalized notifications within the Solutio platform. It generates a unique notification for a specific target user, originating from a designated sender. The function encapsulates the process of notification encoding, unique identifier generation, and document storage within the Juno database, ensuring the notification is correctly directed and accessible to the intended recipient. 
   
    10. [createGlobalNotification()](https://forum.solutio.one/-181/createglobalnotification-documentation): Crafted to broadcast a notification related to a specific idea on the Solutio platform to all users following that idea. By generating a unique notification ID and associating the notification with the idea's ID, the function ensures that any relevant updates or information about the idea are disseminated efficiently to interested users.
        
    12. generate_random_uuid()(): This function generates random strings to be used as keys for notifications documents within our Juno Satellite. There's no documentation for this one because its a simple function. Worth to note that uses an external library called [UUID](https://github.com/aviate-labs/uuid.mo/blob/main/README.md) from [aviate-labs](https://github.com/aviate-labs).

- `src/solutio_escrow`
Houses the Motoko source code responsible for the escrow logic within Solutio. This is where the financial interactions between users are managed, including transactions, approvals, and reputation updates. Key files and functions include:
  - `main.mo`: The central hub for escrow operations. Here are the crucial functions of it:  
    Apologies for the oversight. Let's format it correctly, including the additional functions you mentioned:

### Solutio Escrow Canister README

#### Project's Folder Walkthrough

- `src/declarations`: Contains the generated declarations for interacting with the canisters.
- `src/solutio_escrow`: Houses Motoko source code for the escrow logic within Solutio. Key files and functions include:
  - `main.mo`: The central hub for escrow operations. Here are the crucial functions it supports:
      1. [claimTokens()](https://forum.solutio.one/-186/claimtokens-documentation): Executes token transfers from pledgers to builders for a completed project.

      2. [solutionCompletion()](https://forum.solutio.one/-187/solutioncompletion-documentation): Marks a solution as completed, claims tokens, updates status, and adjusts counters.

      3. [verifyAndStoreTransaction()](https://forum.solutio.one/-195/verifyandstoretransaction-documentation): Verifies a transaction's existence on the ledger and stores its details.

      4. [getProjectRevenue()](https://forum.solutio.one/-196/getprojectrevenue-documentation): Calculates total revenue generated for a project by summing successful transactions.

      5. [getUserRevenue()](https://forum.solutio.one/-197/getuserrevenue-documentation): Calculates total revenue accrued by a user from successful transactions where they are the target.

      6. [getUserSpending()](https://forum.solutio.one/-198/getuserspending-documentation): Calculates the total spending of a user by summing all successful transactions initiated by them.

      7. [getUserReputation()](https://forum.solutio.one/-201/getuserreputation-documentation): Retrieves the reputation score and details of a specified user.

      8. [editReputation()](https://forum.solutio.one/-200/editreputation-documentation): Adjusts a user's reputation based on new and previous transaction figures.

      9. [updateReputation()](https://forum.solutio.one/-199/updateReputation-documentation): Updates a user's reputation based on actual payments versus promised contributions.

      10. [editApproval()](https://forum.solutio.one/-203/editapprovals-documentation): Modifies existing project approvals by a specific sender.|

      11. [removeApprovals_bySender()](https://forum.solutio.one/-204/removeapprovalsbysender-documentation): Removes all approvals initiated by a specified sender for a given project.

      12. [updateAllReputations()](https://forum.solutio.one/-202/updateallreputations-documentation): Updates the reputation of multiple users based on their contributions to a completed project.

      13. [solutionsCompletedCounter()](https://forum.solutio.one/-173/solutionscompletedcounter-documentation): Updates the count of completed solutions within the platform.

      14. [ideaRevenueCounter()](https://forum.solutio.one/-175/idearevenuecounter-documentation): Updates the revenue counter for a specific idea on the platform.

      15. [updateSolutionStatus()](https://forum.solutio.one/-176/updatesolutionstatus-documentation): Changes the status of a solution within the platform.

      16. [storeTransaction()](https://forum.solutio.one/-183/storetransaction-documentation): Registers a new transaction within the escrow system.

      17. [getTransactionsBySender()](https://forum.solutio.one/-184/gettransactionsbysender-documentation): Retrieves a list of transactions initiated by a specific sender.

      18. [getTransactionsByTarget()](https://forum.solutio.one/-188/gettransactionsbytarget-documentation): Retrieves a list of transactions where the specified principal is the target.

      19. [getTransactionsByProject()](https://forum.solutio.one/-189/gettransactionsbyproject-documentation): Retrieves a list of transactions associated with a specific project.

      20. [storeApprovals()](https://forum.solutio.one/-190/storeapprovals-documentation): Stores a list of user approvals for a specific project.

      21. [getApprovals()](https://forum.solutio.one/-185/getapprovals-documentation): Retrieves all approval transactions associated with a specific project.

      22. [getProjectsApprovals_bySender()](https://forum.solutio.one/-191/getprojectsapprovalsbysender-documentation): Retrieves approvals made by a specific sender for a particular project.

      23. [getProjectsApprovals_byTarget()](https://forum.solutio.one/-192/getprojectsapprovalsbytarget-documentation): Retrieves approvals targeted towards a specific recipient within a project.

      24. [getProjectApprovals_lowerThan()](https://forum.solutio.one/-193/getprojectapprovalslowerthan-documentation): Retrieves approvals for a given project with amounts less than or equal to a specified threshold.

      25. [getProjectApprovals_majorThan()](https://forum.solutio.one/-194/getprojectapprovalsmajorthan-documentation): Retrieves approvals for a project with amounts greater than a specified threshold.

This detailed breakdown

## Solutio's ecosystem interaction overview

<img src="Canisters interaction .jpg" alt="Alt Text" width="500">

## Solutio's software architecture overview

<img src="Solutio_architecture_overview.jpg" alt="Alt Text" width="500">

## Getting Started

### Prerequisites

- Node.js and npm
- DFX

### Setup

1. Clone the repository and navigate into the project directory:

```bash
git clone [repository_url]
cd [project_name]
```
2. Install dependencies:

```bash
npm install
```

3. Start the DFX local network:

```bash
dfx start --clean
```
4. Deploy the canisters to the local network:

```bash
dfx deploy
```

## Contributing
Contributions are welcome! Please, include feature requests with your improvements [here](https://forum.solutio.one/top/feedback). 

## Links
- Developer: [Bautista Martinez](https://github.com/Bautista1999/solut/commits?author=Bautista1999)
- Project front-end: https://github.com/Bautista1999/solut/blob/main/README.md
- Solutio's webpage: https://xh6qb-uyaaa-aaaal-acuaq-cai.icp0.io/
- Solutio's homepage: https://home.solutio.one/
- Juno: https://juno.build
