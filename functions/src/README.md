# Cloud Functions Plan (Optional)

To make folder sharing robust at scale, consider adding Cloud Functions:

1) onSharedItemAccepted-folder
- Trigger: onWrite of /shared_items/{shareId} where type==folder and status changed to accepted
- Action: Create child shared_items for each noteId in the folder for the recipient

2) onFolderNotesChanged
- Trigger: onUpdate of /users/{ownerId}/folders/{folderId} when noteIds changes
- Action: For each recipient with accepted folder share, create/delete note-level shared_items

3) onFolderShareRevokedOrLeft
- Trigger: onWrite of /shared_items/{shareId} where type==folder and status changes to revoked/left
- Action: Update child note-level shared_items with matching metadata.fromFolder to the same status

This ensures new notes added to a shared folder are propagated and revocations cascade automatically.
